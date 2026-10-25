# Playback cache: Plex and Jellyfin read through mini's SSD, not the Unraid
# disks.
#
#   1. FS-Cache: /media (the read-only NFS mount that Plex and Jellyfin play
#      from) gets the `fsc` option. The kernel keeps the data it reads in
#      /var/cache/fscache and serves later reads from there, also after a
#      reboot. /data stays uncached: the Arr apps write there.
#   2. media-prefetch: when playback starts, it reads the whole file once.
#      The Unraid disk delivers the file in one burst, then playback reads
#      from the SSD and the disk spins down.
#
# cachefilesd limits the cache by free space on its filesystem, not by size.
# The cache therefore gets its own filesystem: a sparse 200 GiB ext4 image
# on /srv. It uses disk space only for cached data, and `discard` gives
# space back when cachefilesd removes old entries.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cacheDir = config.services.cachefilesd.cacheDir;
  image = "/srv/fscache.img";
  imageSize = "200G";

  # Larger files are not prefetched, so one file cannot evict the whole cache.
  maxPrefetchBytes = 80 * 1024 * 1024 * 1024;
  pollSeconds = 15;

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;
in
{
  services.cachefilesd = {
    enable = true;
    # Percentages of the 200 GiB image: cull below 7 % free, stop at 3 %.
    extraConfig = ''
      brun 10%
      bcull 7%
      bstop 3%
    '';
  };

  fileSystems."/media".options = [
    "fsc"
    # The cache must be live when the NFS superblock is created.
    "x-systemd.after=cachefilesd.service"
  ];

  systemd.services = {
    # Creates the image on first start and loop-mounts it on the cache dir.
    # Changing imageSize later does not resize an existing image.
    fscache-storage = {
      description = "Loop-mount the 200 GiB FS-Cache image";
      after = [ "srv.mount" ];
      requires = [ "srv.mount" ];
      before = [ "cachefilesd.service" ];
      path = [
        pkgs.coreutils
        pkgs.e2fsprogs
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.util-linux}/bin/umount ${cacheDir}";
      };
      script = ''
        set -euo pipefail
        if [ ! -e ${image} ]; then
          touch ${image}
          # No copy-on-write: no fragmentation from the cache's small writes.
          chattr +C ${image}
          truncate -s ${imageSize} ${image}
          mkfs.ext4 -q -L fscache -m 0 ${image}
        fi
        mkdir -p ${cacheDir}
        mountpoint -q ${cacheDir} || mount -o loop,noatime,discard ${image} ${cacheDir}
      '';
    };

    cachefilesd = {
      requires = [ "fscache-storage.service" ];
      after = [ "fscache-storage.service" ];
    };

    media-prefetch = {
      description = "Read playing media into the FS-Cache in one pass";
      after = [
        "plex.service"
        "jellyfin.service"
        "cachefilesd.service"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.RequiresMountsFor = [ "/media" ];
      serviceConfig = {
        DynamicUser = true;
        Restart = "always";
        RestartSec = 30;
        RuntimeDirectory = "media-prefetch";
        LoadCredential = [
          "plex-token:${config.sops.secrets."mini/media/plex/token".path}"
          "jellyfin-api-key:${config.sops.secrets."mini/media/jellyfin/api-key".path}"
        ];
        Nice = 19;
        IOSchedulingClass = "idle";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      script = ''
        set -uo pipefail

        # Header files, so the tokens are not on a command line.
        umask 077
        printf 'X-Plex-Token: %s\n' "$(<"$CREDENTIALS_DIRECTORY/plex-token")" >"$RUNTIME_DIRECTORY/plex"
        printf 'X-Emby-Token: %s\n' "$(<"$CREDENTIALS_DIRECTORY/jellyfin-api-key")" >"$RUNTIME_DIRECTORY/jellyfin"

        # File paths of everything playing now, on Plex and on Jellyfin.
        playing() {
          ${curl} -sf --max-time 10 -H @"$RUNTIME_DIRECTORY/plex" -H "Accept: application/json" \
            http://127.0.0.1:32400/status/sessions \
            | ${jq} -r '.MediaContainer.Metadata[]?.Media[]?.Part[]?.file // empty' || true
          ${curl} -sf --max-time 10 -H @"$RUNTIME_DIRECTORY/jellyfin" \
            "http://127.0.0.1:8096/Sessions?activeWithinSeconds=60" \
            | ${jq} -r '.[].NowPlayingItem.Path // empty' || true
        }

        # Path + mtime + size, so a replaced file is read again.
        declare -A seen
        while true; do
          while IFS= read -r file; do
            case "$file" in /media/*) ;; *) continue ;; esac
            [ -f "$file" ] || continue
            read -r mtime size < <(stat -c '%Y %s' "$file") || continue
            key="$file|$mtime|$size"
            [ -n "''${seen[$key]:-}" ] && continue
            seen[$key]=1
            if [ "$size" -gt ${toString maxPrefetchBytes} ]; then
              echo "skip, larger than the limit: $file"
              continue
            fi
            echo "prefetch $((size / 1024 / 1024)) MiB: $file"
            start=$SECONDS
            if dd if="$file" of=/dev/null bs=16M status=none; then
              echo "cached in $((SECONDS - start)) s: $file"
            else
              echo "failed: $file"
              unset "seen[$key]"
            fi
          done < <(playing | sort -u)
          sleep ${toString pollSeconds}
        done
      '';
    };
  };
}
