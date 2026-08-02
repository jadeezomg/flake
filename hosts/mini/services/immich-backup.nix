# Off-host backup of the Immich library + database to the Unraid array.
#
# Docs: docs/hosts/mini.md § Immich → Backup
#
# TRANSPORT: restic over SFTP to root@192.168.178.62:/mnt/user/backup/immich.
#
#   Deliberately NOT an NFS mount. ./media/storage.nix documents how an
#   NFS-backed path inside a systemd namespace wedges this host (idle-timeout
#   -> ESTALE -> 226/NAMESPACE). Worse for a backup: `hard` NFS means an Unraid
#   stall blocks restic in uninterruptible sleep forever with no timeout and no
#   failure, and a restic `local:` repo whose mount is missing will cheerfully
#   initialise a SECOND, EMPTY repo on the local disk and orphan the real one.
#   ssh fails fast and loud instead.
#
#   Deliberately NOT borg, despite docs/nix/builders-cache-backups-plan.md § 4.
#   Borg needs `borg serve` on the far end (a container to maintain on an
#   appliance whose /root is tmpfs) or a repo on a filesystem it controls; borg
#   upstream does not support repos on network filesystems. restic's sftp
#   backend needs nothing on Unraid but the stock sftp-server. That plan is the
#   opposite direction (clients -> mini as a repo), where mini owns a real local
#   filesystem — it can still be borg. The two choices need not match.
#
#   Deliberately NOT an rsync mirror: a mirror replicates deletion, which is
#   half the threat model (Immich regression, an errant phone delete, malware).
#   For a browsable file view use `just mini immich-backup-mount`, which browses
#   ANY snapshot and costs zero extra bytes on Unraid.
#
# ORDERING: database first, filesystem second, per Immich's docs. The dump runs
# as backupPrepareCommand (systemd ExecStartPre), so a failed dump ABORTS the
# snapshot — we never store media without a matching database. The worst case is
# then "files on disk the DB doesn't know about" (recoverable) rather than "DB
# rows pointing at files not in the snapshot" (permanently broken assets).
#
# THREE UNITS:
#   restic-backups-immich        nightly 03:15 — pg_dump, then snapshot
#   restic-backups-immich-maint  monthly       — forget --prune + check
#   immich-backup-watchdog       daily  09:00  — asks the REPO for a fresh snapshot
#
# The watchdog is not redundant with OnFailure=. A green timer proves nothing if
# the unit was masked, if mini was powered off for a week, or if the repo was
# replaced. It is the only end-to-end check.
#
# MANUAL UNRAID PREREQUISITES (one time, before the first deploy):
#   1. On mini, generate the keypair IN TMPFS — sops is the private key's only
#      permanent home, and mini's /tmp is NOT tmpfs (boot.tmp.useTmpfs = false,
#      cleanOnBoot = false): it is the btrfs root, where copy-on-write also
#      makes `shred` unreliable. /dev/shm is RAM, and the only swap is zram.
#        sudo ssh-keygen -t ed25519 -N '' -C 'mini@immich-backup' -f /dev/shm/k
#        sudo cat /dev/shm/k.pub   # -> Unraid WebGUI, see below
#        sudo cat /dev/shm/k       # -> sops, mini/backup/unraid-ssh-key
#        sudo shred -u /dev/shm/k /dev/shm/k.pub
#      Paste the PUBLIC key into Unraid WebGUI -> Users -> root -> "SSH
#      authorized keys". Required: /root is tmpfs on Unraid, so appending to
#      authorized_keys by hand does not survive a reboot there.
#   2. WebGUI -> Shares -> Add Share `backup`; cache No, SMB No, NFS No.
#      Not exporting it is the point: the only access path is the SSH key.
#   3. In a shell ON Unraid: mkdir -p /mnt/user/backup/immich
#      (not `ssh root@192.168.178.62 ...` from Unraid itself — that loops back
#      and prompts for the root password.)
#   4. Settings -> Disk Settings -> md_write_method = "reconstruct write".
#      Parity read/modify/write caps the initial seed at ~40-80 MB/s.
{
  config,
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  immich = config.services.immich;
  media = immich.mediaLocation; # /srv/immich
  dumpDir = "${media}/backups";

  # Shared with the media NFS mounts and the ssh alias — see
  # data/network/lan-hosts.nix. Unraid is not flake-managed, so it has no
  # hosts/<name>/host.nix to hold this.
  #
  # We use .lan, not .tailnet: restic encrypts client-side and ssh wraps the
  # transport, so Tailscale would add confidentiality we already have plus
  # userspace-WireGuard CPU on a multi-hundred-GB seed — and Tailscale SSH's
  # periodic re-auth check blocks non-interactive runs outright. Point HostName
  # at .tailnet if the LAN path ever dies; nothing else changes.
  inherit (dotfilesLib.lanHosts) unraid;
  sshAlias = "unraid-backup";
  repository = "sftp:${sshAlias}:${unraid.shareRoot}/backup/immich";
  passwordFile = config.sops.secrets."mini/backup/restic-password".path;

  # ssh writes known_hosts here; /root is unreachable under ProtectHome.
  sshStateDir = "/var/lib/immich-backup";

  # ── Database dump ──────────────────────────────────────────────────────────
  dbDump = pkgs.writeShellApplication {
    name = "immich-db-dump";
    runtimeInputs = with pkgs; [
      coreutils
      gzip
      gnugrep
      util-linux
      config.services.postgresql.package
    ];
    text = ''
      umask 0077
      dir=${lib.escapeShellArg dumpDir}
      stamp=$(date -u +%Y%m%dT%H%M%SZ)
      out="$dir/immich-db-backup-$stamp.sql.gz"
      tmp="$dir/.immich-db-backup-$stamp.sql.gz.part"

      install -d -o ${immich.user} -g ${immich.group} -m 0700 "$dir"

      # NEVER add /var/lib/postgresql to the restic paths. A filesystem copy of
      # a live $PGDATA is torn pages plus a mid-stream WAL, and it is
      # version-locked to the exact vchord.so/pgvector build in the store at
      # that instant. The dump is the backup; the data directory is not.
      #
      # setpriv, not su/runuser: those go through PAM, which does not enjoy
      # ProtectSystem=strict + ProtectHome. Flags are verbatim from Immich's docs.
      #
      # --rsyncable is load-bearing. Plain gzip produces a wholly different byte
      # stream for a one-row change, so restic would store a full fresh copy
      # every night across 34 retained snapshots. --rsyncable restarts the
      # deflate window at content boundaries, so today's dump chunks almost
      # identically to yesterday's and restic stores a delta instead.
      if ! setpriv --reuid ${config.services.postgresql.superUser} \
                   --regid ${config.services.postgresql.superUser} --clear-groups \
             pg_dump --clean --if-exists --dbname=${immich.database.name} \
           | gzip --rsyncable -6 > "$tmp"; then
        rm -f "$tmp"
        echo "immich-db-dump: pg_dump failed — refusing to publish" >&2
        exit 1
      fi

      # Two gates against the classic silent failure: a truncated dump that
      # still gunzips cleanly. The marker is pg_dump's literal final line.
      gzip -t "$tmp"
      if ! gzip -cd "$tmp" | tail -n 5 | grep -q '^-- PostgreSQL database dump complete'; then
        rm -f "$tmp"
        echo "immich-db-dump: no completion marker — dump is truncated" >&2
        exit 1
      fi

      chown ${immich.user}:${immich.group} "$tmp"
      chmod 0600 "$tmp"
      mv -f "$tmp" "$out" # same filesystem -> atomic; restic never sees a partial

      # Short local tail only; restic holds the real history off-host. Names are
      # basic-ISO UTC, so lexical sort == chronological sort.
      shopt -s nullglob
      mapfile -t dumps < <(printf '%s\n' "$dir"/immich-db-backup-*.sql.gz | sort -r)
      if [ "''${#dumps[@]}" -gt 3 ]; then
        rm -f -- "''${dumps[@]:3}"
      fi
      rm -f -- "$dir"/.immich-db-backup-*.part 2>/dev/null || true

      echo "immich-db-dump: wrote $out ($(du -h "$out" | cut -f1))"
    '';
  };

  # ── Freshness watchdog ─────────────────────────────────────────────────────
  watchdog = pkgs.writeShellApplication {
    name = "immich-backup-watchdog";
    runtimeInputs = with pkgs; [
      restic
      jq
      coreutils
      openssh
    ];
    text = ''
      max_age_hours=36

      latest=$(restic snapshots --json --latest 1 --tag immich \
        | jq -r 'if length == 0 then "" else .[0].time end')

      if [ -z "$latest" ]; then
        echo "immich-backup-watchdog: repo has NO tagged snapshots at all" >&2
        exit 1
      fi

      age=$(( ( $(date +%s) - $(date -d "$latest" +%s) ) / 3600 ))
      echo "immich-backup-watchdog: newest snapshot $latest (''${age}h old)"
      if [ "$age" -gt "$max_age_hours" ]; then
        echo "immich-backup-watchdog: STALE — older than ''${max_age_hours}h" >&2
        exit 1
      fi
    '';
  };

  # ── Failure notifier ───────────────────────────────────────────────────────
  # Posts to the local continuwuity (./matrix.nix, loopback :6167). Sends an
  # unencrypted m.notice, so point it at a NON-E2EE room.
  notify = pkgs.writeShellApplication {
    name = "backup-notify";
    runtimeInputs = with pkgs; [
      curl
      jq
      coreutils
      systemd
    ];
    text = ''
      unit="''${1:?usage: backup-notify <unit>}"

      if [ -z "''${MATRIX_ROOM:-}" ] || [ -z "''${MATRIX_TOKEN:-}" ]; then
        echo "backup-notify: mini/backup/matrix-notify not populated; unit=$unit failed" >&2
        exit 0 # never let the notifier itself go red and add noise
      fi

      tail=$(journalctl -u "$unit" -n 25 --no-pager -o cat 2>/dev/null | tail -c 2500)
      body=$(printf '%s FAILED on mini\n\n%s' "$unit" "$tail")

      curl -fsS -X PUT --max-time 20 \
        -H "Authorization: Bearer $MATRIX_TOKEN" \
        -H 'Content-Type: application/json' \
        --data "$(jq -nc --arg b "$body" '{msgtype:"m.notice", body:$b}')" \
        "http://127.0.0.1:6167/_matrix/client/v3/rooms/$MATRIX_ROOM/send/m.room.message/$(date +%s%N)" \
        >/dev/null
    '';
  };
in
{
  # restic's sftp backend shells out to `ssh <host> -s sftp`, so the repository
  # URL carries no key, port or options — everything must live in ssh_config.
  # Global rather than root's ~/.ssh/config because the units run with
  # ProtectHome=true. The alias is namespaced so it cannot collide with the
  # `unraid` Home Manager alias in data/network/ssh-destinations.nix.
  programs.ssh.extraConfig = ''

    Host ${sshAlias}
      HostName ${unraid.lan}
      User ${unraid.sshUser}
      IdentityFile ${config.sops.secrets."mini/backup/unraid-ssh-key".path}
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
      UserKnownHostsFile ${sshStateDir}/known_hosts
      ServerAliveInterval 30
      ServerAliveCountMax 6
      Compression no
  '';

  systemd.tmpfiles.settings.immich-backup.${sshStateDir}.d = {
    user = "root";
    group = "root";
    mode = "0700";
  };

  # ── Nightly: dump, then snapshot ───────────────────────────────────────────
  services.restic.backups.immich = {
    inherit repository passwordFile;
    initialize = true;
    paths = [ media ];
    exclude = [ "${dumpDir}/.*.part" ]; # in-flight dump staging

    # Must carry a shebang: the restic module does pkgs.writeScript on this
    # string and execs the bare store path, so a script without #! is ENOEXEC.
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      exec ${lib.getExe dbDump}
    '';

    extraBackupArgs = [
      "--tag immich"
      "--exclude-caches"
      # /srv is NVMe; restic's default read-concurrency of 2 leaves it idle.
      "--read-concurrency 8"
    ];

    # No forget and no check on the nightly run: pruning a multi-TB sftp repo
    # rewrites pack files across a parity array, and check re-reads the index
    # over the wire. Both live in immich-maint below.
    pruneOpts = [ ];
    runCheck = false;

    timerConfig = {
      OnCalendar = "*-*-* 03:15:00";
      RandomizedDelaySec = "15m";
      Persistent = true; # mini was off -> catch up on next boot
    };
  };

  # ── Monthly: retention + integrity ─────────────────────────────────────────
  services.restic.backups.immich-maint = {
    inherit repository passwordFile;
    paths = null; # forget/prune/check only, no new snapshot
    initialize = false;
    createWrapper = false; # one `restic-immich` in PATH is enough

    # --tag immich scopes forget to our snapshots, so a future job sharing this
    # repo cannot be pruned away by accident. --prune is still repo-global.
    pruneOpts = [
      "--tag immich"
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
      "--keep-yearly 3"
    ];

    runCheck = true;
    # A full --read-data pulls the entire library back over the wire. 5%/month
    # rotates through everything in ~20 months and is the only thing that
    # catches array bit rot BEFORE a restore does.
    checkOpts = [ "--read-data-subset=5%" ];

    timerConfig = {
      OnCalendar = "Sun *-*-01..07 04:30:00"; # first Sunday
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };

  # 64 MiB packs instead of the 16 MiB default: 4x fewer files landing on the
  # parity array and in shfs's directory tree, at no cost to restore granularity.
  systemd.services.restic-backups-immich.environment.RESTIC_PACK_SIZE = "64";
  systemd.services.restic-backups-immich-maint.environment.RESTIC_PACK_SIZE = "64";

  # NOTE: no `~@privileged` in SystemCallFilter — the dump uses setpriv, which
  # needs setuid/setgid. CapabilityBoundingSet is the narrower control here.
  systemd.services.restic-backups-immich = {
    onFailure = [ "backup-notify@%n.service" ];
    serviceConfig = {
      ReadWritePaths = [
        dumpDir
        sshStateDir
      ];
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectProc = "invisible";
      PrivateDevices = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      CapabilityBoundingSet = [
        "CAP_DAC_READ_SEARCH" # walk the whole 0700 immich tree
        "CAP_CHOWN"
        "CAP_FOWNER"
        "CAP_SETUID" # setpriv -> postgres
        "CAP_SETGID"
      ];
      # Don't fight llama-cpp / jellyfin transcodes for the box at 03:15.
      CPUSchedulingPolicy = "batch";
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      # A seed can legitimately run for hours; a wedge must not run forever.
      TimeoutStartSec = "12h";
    };
  };

  systemd.services.restic-backups-immich-maint = {
    onFailure = [ "backup-notify@%n.service" ];
    serviceConfig = {
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ sshStateDir ];
      PrivateDevices = true;
      CPUSchedulingPolicy = "batch";
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      TimeoutStartSec = "8h";
    };
  };

  # ── Watchdog ───────────────────────────────────────────────────────────────
  systemd.services.immich-backup-watchdog = {
    description = "Alarm if the Immich restic repo has no fresh snapshot";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    onFailure = [ "backup-notify@%n.service" ];
    path = [ config.programs.ssh.package ];
    environment = {
      RESTIC_REPOSITORY = repository;
      RESTIC_PASSWORD_FILE = passwordFile;
      RESTIC_CACHE_DIR = "/var/cache/immich-backup-watchdog";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe watchdog;
      CacheDirectory = "immich-backup-watchdog";
      ReadWritePaths = [ sshStateDir ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      TimeoutStartSec = "10m";
    };
  };

  systemd.timers.immich-backup-watchdog = {
    description = "Daily Immich backup freshness check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };

  # Template unit, instanced by OnFailure=backup-notify@%n.service.
  systemd.services."backup-notify@" = {
    description = "Post a Matrix notice that %I failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe notify} %I";
      EnvironmentFile = "-${config.sops.secrets."mini/backup/matrix-notify".path}";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      TimeoutStartSec = "1m";
    };
  };

  # Declared unconditionally: sops-nix decrypts at activation, not eval, so this
  # evaluates before the values exist (same reasoning as ../flake-cache-warm.nix).
  sops.secrets = {
    "mini/backup/restic-password".mode = "0400";
    "mini/backup/unraid-ssh-key".mode = "0400";
    "mini/backup/matrix-notify".mode = "0400";
  };
}
