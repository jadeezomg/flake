{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Radarr and Sonarr share these settings (Settings -> Media Management).
  mediaManagement = {
    # Deleted and upgraded files wait here for 7 days. Created by
    # nixflix-setup-remote-dirs (../nixflix/common.nix), after the NFS mount.
    recycleBin = "/data/media/.recycle";
    recycleBinCleanupDays = 7;
    # Import subtitles that ship with a release. Bazarr fills the gaps.
    importExtraFiles = true;
    extraFileExtensions = "srt,ass,ssa,sub,idx";
    # The scheduled refresh (every 12 h) would re-read every media folder and
    # spin up the Unraid array. Imports do not need it.
    rescanAfterRefresh = "afterManual";
  };
  # Media is deleted by hand (Plex, Jellyfin, files). Without this, the app
  # sees the file missing and downloads it again. Upgrades are not affected.
  unmonitorDeleted = field: { ${field} = true; };

  # nixflix's mediamanagement and delayprofiles units, unlike its other API
  # units, do not wait for the app. When a deploy restarted the apps, they
  # ran before the API listened and failed with "couldn't connect"
  # (2026-10-25). This orders them after the app and waits for /ping.
  waitForApi = app: port: {
    after = [ "${app}.service" ];
    preStart = ''
      for _ in $(seq 120); do
        ${lib.getExe pkgs.curl} -sf --max-time 2 http://127.0.0.1:${toString port}/ping >/dev/null && exit 0
        sleep 1
      done
      echo "${app} did not answer on port ${toString port}" >&2
      exit 1
    '';
    onFailure = [ "ntfy-alert@%n.service" ];
  };
  arrPorts = {
    radarr = 7878;
    sonarr = 8989;
    lidarr = 8686;
  };
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
        mediaManagement = mediaManagement // unmonitorDeleted "autoUnmonitorPreviouslyDownloadedEpisodes";
        # .plexmatch files pin each series to its TVDB ID for Plex matching.
        metadata.PlexMetadata.enable = true;
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
        mediaManagement = mediaManagement // unmonitorDeleted "autoUnmonitorPreviouslyDownloadedMovies";
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
        # Lidarr replaces FLACs with MP3-320 (lidarr-profiles.nix); replaced
        # files wait here for 7 days. Same share as /Music, so moves are cheap.
        mediaManagement = {
          recycleBin = "/Music/.recycle";
          recycleBinCleanupDays = 7;
        }
        // unmonitorDeleted "autoUnmonitorPreviouslyDownloadedTracks";
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
        # Priority breaks ties between equal releases: lower wins. Usenet
        # first, then Nyaa (most anime), then the general torrent sites.
        indexers = [
          {
            name = "1337x";
            priority = 40;
            # 1337x is behind Cloudflare. Prowlarr sends indexers with the
            # flaresolverr tag through FlareSolverr.
            tags = [
              "1337x"
              "flaresolverr"
            ];
          }
          {
            name = "NZBgeek";
            priority = 10;
            apiKey._secret = config.sops.secrets."mini/media/prowlarr/indexers/nzbgeek-api-key".path;
            # Prowlarr shows a health error after this date. Update it on renewal.
            vipExpiration = "2031-07-21";
            tags = [ "nzbgeek" ];
          }
          # Formerly SceneNZBs (renamed in July 2026, same API on a new domain).
          # Prowlarr has no preset for it, so it uses Generic Newznab.
          {
            name = "Treasure Maps";
            priority = 15;
            schemaName = "Generic Newznab";
            baseUrl = "https://treasure-maps.com";
            apiPath = "/api";
            apiKey._secret = config.sops.secrets."mini/media/prowlarr/indexers/treasuremaps-api-key".path;
            vipExpiration = "2027-10-20";
            tags = [ "treasuremaps" ];
          }
          {
            name = "Nyaa.si";
            priority = 30;
            tags = [ "nyaa" ];
          }
          {
            name = "sukebei.nyaa.si";
            priority = 45;
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

  systemd.services =
    lib.concatMapAttrs (app: port: {
      "${app}-mediamanagement" = waitForApi app port;
      "${app}-delayprofiles" = waitForApi app port;
    }) arrPorts
    // {
      # Upstream's reconciler returns 1 after successfully updating every indexer.
      prowlarr-indexers.serviceConfig.SuccessExitStatus = [ 1 ];

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
