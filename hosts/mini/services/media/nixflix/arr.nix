{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Upstream's <app>-rootfolders oneshot has no API readiness gate of its own: it only
  # orders after <app>-config.service, whose wait-for-api ExecStartPost runs when THAT
  # unit (re)starts. -rootfolders also Requires the media mounts, so remounting /media
  # re-runs it while <app>.service is still coming back up — and -config stays active
  # (RemainAfterExit), so nothing waits. Its first `curl -Sf .../rootfolder` then hits a
  # dead port and `set -e` kills the oneshot with exit 7 (seen 2026-07-31 and 2026-07-25).
  # Gate each one on the app's own unauthenticated /ping (no API key needed).
  waitForArrApi =
    app:
    let
      inherit (config.nixflix.${app}.config) hostConfig;
      url = "http://${hostConfig.bindAddress}:${toString hostConfig.port}${hostConfig.urlBase}/ping";
    in
    pkgs.writeShellScript "${app}-rootfolders-wait-for-api" ''
      for i in $(seq 1 90); do
        if ${pkgs.curl}/bin/curl -fsS -o /dev/null ${lib.escapeShellArg url}; then
          exit 0
        fi
        sleep 1
      done
      echo "${app} API at ${url} not ready after 90s" >&2
      exit 1
    '';
in
{
  nixflix = {
    sonarr = {
      enable = true;
      group = "users";
      mediaDirs = [
        "/data/media/Series"
        "/data/media/Anime"
        "/data/media/Series-PtBr"
      ];
      config = {
        apiKey._secret = config.sops.secrets."mini/media/sonarr/api-key".path;
        hostConfig = {
          bindAddress = "127.0.0.1";
          password._secret = config.sops.secrets."mini/media/sonarr/password".path;
        };
      };
    };

    radarr = {
      enable = true;
      group = "users";
      mediaDirs = [ "/data/media/Cinema" ];
      config = {
        apiKey._secret = config.sops.secrets."mini/media/radarr/api-key".path;
        hostConfig = {
          bindAddress = "127.0.0.1";
          password._secret = config.sops.secrets."mini/media/radarr/password".path;
        };
      };
    };

    lidarr = {
      enable = true;
      group = "users";
      mediaDirs = [ "/Music" ];
      config = {
        apiKey._secret = config.sops.secrets."mini/media/lidarr/api-key".path;
        hostConfig = {
          bindAddress = "127.0.0.1";
          password._secret = config.sops.secrets."mini/media/lidarr/password".path;
        };
      };
    };

    prowlarr = {
      enable = true;
      group = "users";
      config = {
        apiKey._secret = config.sops.secrets."mini/media/prowlarr/api-key".path;
        hostConfig = {
          bindAddress = "127.0.0.1";
          password._secret = config.sops.secrets."mini/media/prowlarr/password".path;
        };
        indexers = [
          {
            name = "1337x";
            tags = [ "1337x" ];
          }
          {
            name = "NZBgeek";
            apiKey._secret = config.sops.secrets."mini/media/prowlarr/indexers/nzbgeek-api-key".path;
            tags = [ "nzbgeek" ];
          }
          {
            name = "SceneNZBs";
            apiKey._secret = config.sops.secrets."mini/media/prowlarr/indexers/scenenzbs-api-key".path;
            tags = [ "scenenzbs" ];
          }
          {
            name = "Nyaa.si";
            tags = [ "nyaa" ];
          }
          {
            name = "sukebei.nyaa.si";
            tags = [ "sukebei" ];
          }
        ];
      };
    };

    flaresolverr.enable = true;
  };

  systemd.tmpfiles.settings = {
    "10-sonarr" = lib.mkForce {
      "/srv/nixflix/sonarr".d = {
        mode = "0755";
        user = "sonarr";
        group = "users";
      };
    };
    "10-radarr" = lib.mkForce {
      "/srv/nixflix/radarr".d = {
        mode = "0755";
        user = "radarr";
        group = "users";
      };
    };
    "10-lidarr" = lib.mkForce {
      "/srv/nixflix/lidarr".d = {
        mode = "0755";
        user = "lidarr";
        group = "users";
      };
    };
  };

  systemd.services = {
    # Upstream's reconciler returns 1 after successfully updating every indexer.
    prowlarr-indexers.serviceConfig.SuccessExitStatus = [ 1 ];

    # See waitForArrApi above.
    sonarr-rootfolders.serviceConfig.ExecStartPre = waitForArrApi "sonarr";
    radarr-rootfolders.serviceConfig.ExecStartPre = waitForArrApi "radarr";
    lidarr-rootfolders.serviceConfig.ExecStartPre = waitForArrApi "lidarr";

    # One ReadWritePaths entry for /data (not per-subdir). Separate systemd binds
    # remount each path and break hardlinks (EXDEV) between torrents/usenet and media.
    # Also avoids /data appearing read-only under ProtectSystem=strict with NFS.
    sonarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/sonarr"
        "/data"
      ];
    };
    radarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/radarr"
        "/data"
      ];
    };
    lidarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/lidarr"
        "/data"
        "/Music"
      ];
    };
    prowlarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [ "/srv/nixflix/prowlarr" ];
    };
  };
}
