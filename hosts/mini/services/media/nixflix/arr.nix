{
  config,
  lib,
  ...
}:
let
  inherit (import ./common.nix) mediaEnabled;
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

  systemd.tmpfiles.settings = lib.mkIf mediaEnabled {
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

  systemd.services = lib.mkIf mediaEnabled {
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
