# Immich — self-hosted photo/video library, migrated off the Unraid Docker
# container. Reachable at https://immich.jadee.fyi.
#
# Docs:   docs/hosts/mini-immich.md
# Policy: docs/adr/0007-immich-library-on-mini.md
#
# Shape: nixpkgs' `services.immich` runs `immich-server` (API + web) and
# `immich-machine-learning` (CLIP + face models, loopback :3003), and pulls in
# this host's FIRST postgresql plus a dedicated redis. Everything talks over
# unix sockets:
#   postgres  /run/postgresql                 peer auth as role `immich`
#   redis     /run/redis-immich/redis.sock    (immich-server gets the redis group)
# Because database.host defaults to the socket path /run/postgresql, the
# module's `!isPostgresUnixSocket -> secretsFile != null` assertion is satisfied
# with no secrets file at all: IMMICH ITSELF NEEDS NO SOPS SECRET. Don't go
# looking for one. (The *backup* job does — see ./immich-backup.nix.)
#
# Exposure: 127.0.0.1:2283, openFirewall = false. The shared Caddy tailnet-node
# proxy (./caddy.nix) fronts it at https://immich.jadee.fyi with a Cloudflare
# DNS-01 cert; `just mini dns-sync` discovers the vhost below and creates the A
# record.
#
# Storage: mediaLocation = /srv/immich on the 2 TB application NVMe, beside
# /srv/nixflix. The layout is 1:1 with Immich's own UPLOAD_LOCATION
# (backups/ encoded-video/ library/ profile/ thumbs/ upload/), so every command
# in the upstream backup/restore docs applies verbatim.
#
# Note this INVERTS ADR-0004 (media payloads live on Unraid): Immich does
# per-asset random IO and needs its DB and filesystem mutually consistent, and
# this host has already been burned by NFS idle-timeout ESTALE wedging a service
# namespace (see the long comment in ./media/storage.nix). So the library is
# local and Unraid becomes the *backup target* instead. See ADR-0007.
#
# Postgres keeps the stock /var/lib/postgresql on the system SSD (~117 GB free):
# the cluster is metadata + embeddings, a few GB. The major is PINNED — it
# otherwise derives from system.stateVersion (26.05 -> 17) and the on-disk
# cluster format is permanent, so an unrelated stateVersion edit must never
# silently ask for a major upgrade. Vector search needs vectorchord (pgvecto.rs
# is gone from nixpkgs); the immich module wires shared_preload_libraries,
# search_path and the CREATE/ALTER EXTENSION ExecStartPost itself.
#
# ── ONE-TIME MIGRATION: RE-IMPORT, NOT DATABASE RESTORE ───────────────────────
# The Unraid instance ran pgvecto.rs (`vectors` 0.3.0), which nixpkgs no longer
# ships at any version, and its schema predates the 1.132->1.136->2.x->3.x
# upgrade chain Immich requires. Restoring that dump here is therefore a
# non-starter twice over. With only ~600 assets, re-importing the originals and
# letting mini regenerate thumbnails, faces and CLIP embeddings costs minutes,
# so we do that instead and accept the loss of albums, face NAMES and shared
# links. Full runbook: docs/hosts/mini-immich.md.
#
#   1. miniImmich = true -> `just mini deploy` -> `just mini dns-sync`.
#   2. Create the admin account at https://immich.jadee.fyi, then mint an API
#      key (Account Settings -> API Keys).
#   3. rsync the ORIGINALS off Unraid (/photos/library + /photos/upload) into a
#      staging dir. Do NOT copy thumbs/ or encoded-video/ — they are derived
#      from the originals and Immich rebuilds them.
#   4. `immich login` + `immich upload --recursive` from the staging dir.
#      Uploads are checksum-deduplicated, so re-running is safe and resumable.
#   5. Verify the asset count matches, then delete the staging dir.
#   6. Leave the Unraid containers STOPPED but intact for a few weeks — with no
#      database restore, they are the only copy of the albums and face names.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "immich.jadee.fyi";
  # Immich's upstream default, free on mini (in use: 443 5055 6167 6767 7878
  # 8000 8080 8090 8096 8282 8686 8989 9696 32400 45876). ML uses :3003.
  port = 2283;
  mediaLocation = "/srv/immich";

  immichPkg = config.services.immich.package;

  # `immich-admin` (change-media-location, list-users, reset-admin-password)
  # needs the server's environment to reach postgres/redis. Two nixpkgs gaps
  # make a wrapper necessary: the connection env only exists inside the systemd
  # unit, and the packaged bin/immich-admin — unlike its bin/server sibling —
  # sets neither IMMICH_BUILD_DATA nor a working directory, so Nest cannot find
  # the bundled geodata. Reaching into lib/node_modules is a packaging detail;
  # if a future immich bump moves it, this breaks loudly and is a one-line fix.
  #
  #   sudo -u immich immich-admin change-media-location
  immich-admin = pkgs.writeShellApplication {
    name = "immich-admin";
    runtimeInputs = [
      config.services.postgresql.package
      pkgs.gzip
    ];
    text = ''
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (n: v: "export ${n}=${lib.escapeShellArg v}") config.services.immich.environment
      )}
      export IMMICH_BUILD_DATA=${immichPkg}/lib/node_modules/immich/build
      cd ${immichPkg}/lib/node_modules/immich
      exec ${lib.getExe' immichPkg "immich-admin"} "$@"
    '';
  };
in
{
  services.immich = {
    enable = true;
    host = "127.0.0.1"; # Caddy is the only door
    inherit port mediaLocation;
    openFirewall = false;

    # Config lives in the database and is edited in the web UI. Setting this to
    # an attrset flips Immich into IMMICH_CONFIG_FILE mode, which greys out the
    # entire admin settings page — a bad trade for declaring a few toggles. The
    # declarative path's one real win is secret injection (`_secret`) for OAuth,
    # which is unused here.
    settings = null;

    # All three default true. Stated explicitly because this is the host's first
    # database and the first reader deserves to see what is being pulled in.
    database.enable = true;
    redis.enable = true;
    machine-learning.enable = true;

    # CPU only — /dev/dri/renderD128 belongs to Plex (QSV) and llama.cpp
    # (Vulkan). Empty list keeps the module's PrivateDevices=true.
    # To opt in: set [ "/dev/dri/renderD128" ], add render+video to the immich
    # user (the module does NOT do it for you), and enable Hardware
    # Acceleration in Admin -> Settings -> Video Transcoding. Note this buys
    # transcoding only: nixpkgs has no OpenVINO immich-machine-learning, so
    # CLIP/face inference stays on CPU either way (fine on 16 cores).
    accelerationDevices = [ ];
  };

  # Pinned deliberately — see the header. stateVersion 26.05 selects 17 today;
  # this makes it explicit so a stateVersion edit cannot propose pg 18 silently
  # and demand an offline pg_upgrade.
  services.postgresql.package = pkgs.postgresql_17;

  # The immich module's tmpfiles entry for mediaLocation is type `e` (adjust an
  # EXISTING path), so nothing creates /srv/immich on a fresh host. Not
  # recursive on purpose: migrated content gets one manual chown during
  # bootstrap rather than a multi-hundred-GB walk on every boot.
  systemd.tmpfiles.rules = [
    "d ${mediaLocation} 0700 immich immich -"
  ];

  # /srv is a separate btrfs filesystem on the application NVMe. Don't let the
  # server start against an unmounted mountpoint and quietly recreate an empty
  # library tree on the root filesystem.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ mediaLocation ];

  # immich-cli is the official uploader and is version-locked to the server by
  # coming from the same nixpkgs — the API contract between them is not stable
  # across majors, so a drifting CLI is a real failure mode. Used for the
  # initial bulk import (docs/hosts/mini-immich.md) and any later one.
  environment.systemPackages = [
    immich-admin
    pkgs.immich-cli
  ];

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    import tsnet
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
