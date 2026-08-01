# Immich — self-hosted photo/video library, at https://immich.jadee.fyi.
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

{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "immich.jadee.fyi";
  # ML uses :3003.
  port = 2283;
  mediaLocation = "/srv/immich";

  immichPkg = config.services.immich.package;

  # `immich-admin` (list-users, reset-admin-password, change-media-location)
  # needs the server's environment to reach postgres/redis. Two nixpkgs gaps
  # make a wrapper necessary: the connection env only exists inside the systemd
  # unit, and the packaged bin/immich-admin — unlike its bin/server sibling —
  # sets neither IMMICH_BUILD_DATA nor a working directory, so Nest cannot find
  # the bundled geodata. Reaching into lib/node_modules is a packaging detail;
  # if a future immich bump moves it, this breaks loudly and is a one-line fix.
  #
  #   sudo -u immich immich-admin list-users
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
  # recursive on purpose — walking the whole library on every boot is not
  # acceptable, and the service owns everything it writes underneath.
  systemd.tmpfiles.rules = [
    "d ${mediaLocation} 0700 immich immich -"
  ];

  # /srv is a separate btrfs filesystem on the application NVMe. Don't let the
  # server start against an unmounted mountpoint and quietly recreate an empty
  # library tree on the root filesystem.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ mediaLocation ];

  environment.systemPackages = [ immich-admin ];

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    import tsnet
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
