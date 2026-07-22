{
  config,
  lib,
  pkgs,
  ...
}:
let
  mediaEnabled = true;

  mountDeps = [
    "data.mount"
    "data-media-Music.mount"
    "Music.mount"
    "media.mount"
  ];

  remoteDirs = [
    "/data/media/Series"
    "/data/media/Anime"
    "/data/media/Series-PtBr"
    "/data/media/Cinema"
    "/data/media/Documentaries Feature"
    "/data/media/Documentaries"
    "/data/media/Comedy"
    "/data/media/Movies"
    "/data/media/Music"
    "/data/torrents"
    "/data/torrents/sonarr"
    "/data/torrents/radarr"
    "/data/torrents/lidarr"
    "/data/torrents/prowlarr"
    "/data/torrents/default"
    "/data/usenet"
    "/data/usenet/incomplete"
    "/data/usenet/complete"
    "/data/usenet/complete/sonarr"
    "/data/usenet/complete/radarr"
    "/data/usenet/complete/lidarr"
    "/data/usenet/complete/prowlarr"
    "/data/usenet/watch"
    "/data/usenet/nzb-backup"
    "/data/usenet/admin"
    "/data/usenet/logs"
  ];

  mkLibrary = collectionType: paths: {
    inherit collectionType paths;
    enableRealtimeMonitor = false;
    # Jellyfin's nightly Audio Normalization task scans every album/track for LUFS
    # metadata; on mini it fails 100% (log spam) while ffmpeg works manually.
    enableLUFSScan = false;
    saveLocalMetadata = false;
    saveSubtitlesWithMedia = false;
    saveLyricsWithMedia = false;
    saveTrickplayWithMedia = false;
  };

  # Search stays inside the VPN netns with qBittorrent (no host-netns escape).
  # Plugins are managed manually via the WebUI under nova3/engines — not declared in Nix.
  # Bare system python3 lacks plugin deps (requests/bs4/lxml); keep a small withPackages env.
  # Wrapper only strips qBittorrent's -I (breaks PYTHONPATH / nova3 `helpers` imports).
  qbittorrentNovaDir = "/var/lib/qBittorrent/qBittorrent/data/nova3";
  qbittorrentSearchPython = pkgs.python3.withPackages (
    ps: with ps; [
      beautifulsoup4
      defusedxml
      html5lib
      lxml
      requests
    ]
  );
  qbittorrentSearchPythonPath = pkgs.writeShellScript "qbittorrent-search-python" ''
    export PYTHONPATH=${qbittorrentNovaDir}
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    args=()
    for arg in "$@"; do
      if [ "$arg" != "-I" ]; then
        args+=("$arg")
      fi
    done
    cd ${qbittorrentNovaDir}/engines
    exec ${qbittorrentSearchPython}/bin/python3 "''${args[@]}"
  '';
in
{
  nixflix = {
    enable = mediaEnabled;
    mediaDir = "/data/media";
    downloadsDir = "/data";
    stateDir = "/srv/nixflix";
    serviceDependencies = mountDeps ++ [ "nixflix-setup-remote-dirs.service" ];

    globals.libraryOwner = {
      user = "unraid";
      group = "users";
    };

    postgres.enable = false;
    caddy.enable = false;
    nginx.enable = false;
    seerr.enable = false;

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

    torrentClients.qbittorrent = {
      enable = true;
      downloadsDir = "/data/torrents";
      webuiPort = 8282;
      vpn.enable = true;
      password._secret = config.sops.secrets."mini/media/qbittorrent/password".path;
      categories = {
        sonarr = "/data/torrents/sonarr";
        radarr = "/data/torrents/radarr";
        lidarr = "/data/torrents/lidarr";
        prowlarr = "/data/torrents/prowlarr";
      };
      serverConfig = {
        # Misc/RSS proxy flags are on but no proxy is configured; keep them off so
        # any future HTTP client inside qBittorrent does not try a blank proxy.
        Network.Proxy.Profiles = {
          Misc = false;
          RSS = false;
        };
        Preferences = {
          WebUI = {
            Username = "admin";
            Password_PBKDF2 = "@ByteArray(UEDQJNvOAG77ID/NZNBFUA==:/iBnGxh7a5EQWn3kApyU2x7Hd8KrwjnzxSK4CQDEJ9bQbxQSDd5oFsroNXX+s2GdGCWFdDXPFZg2e07aH0wPvA==)";
          };
          Search = {
            # qBittorrent 5.x reads Preferences/Search/pythonExecutablePath (not PythonExecutable).
            # Store-path wrapper; search traffic stays in the VPN netns with the daemon.
            pythonExecutablePath = "${qbittorrentSearchPythonPath}";
          };
        };
      };
    };

    usenetClients.sabnzbd = {
      enable = true;
      downloadsDir = "/data/usenet";
      vpn.enable = true;
      settings = {
        misc = {
          api_key._secret = config.sops.secrets."mini/media/sabnzbd/api-key".path;
          nzb_key._secret = config.sops.secrets."mini/media/sabnzbd/nzb-key".path;
          username._secret = config.sops.secrets."mini/media/sabnzbd/username".path;
          password._secret = config.sops.secrets."mini/media/sabnzbd/password".path;
          download_dir = "/data/usenet/incomplete";
          complete_dir = "/data/usenet/complete";
          host_whitelist = "sabnzbd.jadee.fyi";
          local_ranges = [
            "192.168.15.0/24"
            "192.168.178.0/24"
            "100.64.0.0/10"
          ];
        };
        servers = [
          {
            name = "Premiumize";
            host = "usenet.premiumize.me";
            port = 563;
            connections = 8;
            ssl = true;
            ssl_verify = 2;
            priority = 0;
            optional = false;
            backup = false;
            username._secret = config.sops.secrets."mini/media/sabnzbd/premiumize-username".path;
            password._secret = config.sops.secrets."mini/media/sabnzbd/premiumize-password".path;
          }
        ];
      };
    };

    vpn = {
      enable = mediaEnabled;
      wgConfFile = config.sops.secrets."mini/media/vpn/wireguard-conf".path;
      accessibleFrom = [
        "192.168.178.0/24"
        "100.64.0.0/10"
      ];
    };

    jellyfin = {
      enable = true;
      dataDir = "/srv/nixflix/jellyfin";
      cacheDir = "/srv/nixflix/jellyfin-cache";
      apiKey._secret = config.sops.secrets."mini/media/jellyfin/api-key".path;

      system.metadataPath = "/srv/nixflix/jellyfin/metadata";
      network = {
        localNetworkAddresses = [ "127.0.0.1" ];
        knownProxies = [ "127.0.0.1" ];
        localNetworkSubnets = [
          "192.168.178.0/24"
          "100.64.0.0/10"
        ];
      };

      users = {
        jadee = {
          mutable = false;
          password._secret = config.sops.secrets."mini/media/jellyfin/users/jadee-password".path;
          policy = {
            isAdministrator = true;
            isHidden = false;
          };
        };
        angeli265 = {
          mutable = false;
          password._secret = config.sops.secrets."mini/media/jellyfin/users/angeli265-password".path;
          policy.isHidden = false;
        };
      };

      encoding = {
        enableHardwareEncoding = true;
        hardwareAccelerationType = "qsv";
        qsvDevice = "/dev/dri/renderD128";
        hardwareDecodingCodecs = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp8"
          "vp9"
          "av1"
        ];
        allowAv1Encoding = false;
        enableIntelLowPowerH264HwEncoder = false;
        enableIntelLowPowerHevcHwEncoder = false;
      };

      libraries = {
        Shows = lib.mkForce null;
        Movies = lib.mkForce (mkLibrary "movies" [ "/media/Cinema" ]);
        Music = lib.mkForce (mkLibrary "music" [ "/media/Music" ]);
        Series = mkLibrary "tvshows" [ "/media/Series" ];
        "ゲーム" = mkLibrary "tvshows" [ "/media/Anime" ];
        "Documentaries Feature" = mkLibrary "movies" [ "/media/Documentaries Feature" ];
        Documentaries = mkLibrary "tvshows" [ "/media/Documentaries" ];
        Comedy = mkLibrary "movies" [ "/media/Comedy" ];
        "Gaming Videos" = mkLibrary "movies" [ "/media/Movies" ];
        "Series-PtBr" = mkLibrary "tvshows" [ "/media/Series-PtBr" ];
      };
    };
  };

  # Drop leftover host-netns setuid helper from earlier revisions.
  system.activationScripts.qbittorrentSearchCleanup = lib.mkIf mediaEnabled ''
    rm -f /var/lib/qBittorrent/bin/qbittorrent-search-netns \
      /var/lib/qBittorrent/bin/python3
  '';

  systemd.tmpfiles.settings = lib.mkIf mediaEnabled {
    "10-nixflix" = lib.mkForce {
      "/srv/nixflix".d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
    };
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
    "10-qbittorrent" = lib.mkForce {
      "/var/lib/qBittorrent".d = {
        mode = "0755";
        user = "qbittorrent";
        group = "users";
      };
      "/var/lib/qBittorrent/qBittorrent/config".d = {
        mode = "0754";
        user = "qbittorrent";
        group = "users";
      };
      "${qbittorrentNovaDir}/engines".d = {
        mode = "0755";
        user = "qbittorrent";
        group = "users";
      };
    };
    "10-sabnzbd" = lib.mkForce {
      "/var/lib/sabnzbd".d = {
        mode = "0755";
        user = "sabnzbd";
        group = "users";
      };
    };
  };

  systemd.services = lib.mkIf mediaEnabled {
    # Upstream's reconciler returns 1 after successfully updating every indexer.
    prowlarr-indexers.serviceConfig.SuccessExitStatus = [ 1 ];

    nixflix-setup-remote-dirs = {
      description = "Create Nixflix directories on mounted Unraid storage";
      after = mountDeps;
      requires = mountDeps;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatMapStringsSep "\n" (
        dir: "${pkgs.coreutils}/bin/install -d -m 0775 -o unraid -g users ${lib.escapeShellArg dir}"
      ) remoteDirs;
    };

    sonarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/sonarr"
        "/data/media/Series"
        "/data/media/Anime"
        "/data/media/Series-PtBr"
        "/data/torrents/sonarr"
        "/data/usenet/complete/sonarr"
      ];
    };
    radarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/radarr"
        "/data/media/Cinema"
        "/data/torrents/radarr"
        "/data/usenet/complete/radarr"
      ];
    };
    lidarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [
        "/srv/nixflix/lidarr"
        "/Music"
        "/data/torrents/lidarr"
        "/data/usenet/complete/lidarr"
      ];
    };
    prowlarr.serviceConfig = {
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = lib.mkForce [ "/srv/nixflix/prowlarr" ];
    };
    qbittorrent.serviceConfig = {
      ProtectSystem = lib.mkForce "strict";
      ReadWritePaths = lib.mkForce [
        "/var/lib/qBittorrent"
        "/data/torrents"
      ];
    };
    jellyfin.serviceConfig = {
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/nixflix/jellyfin"
        "/srv/nixflix/jellyfin-cache"
      ];
      ReadOnlyPaths = [ "/media" ];
      InaccessiblePaths = [
        "/data"
        "/Music"
      ];
    };

    sabnzbd = {
      after = mountDeps;
      requires = mountDeps;
      serviceConfig.BindPaths = [ "/data/usenet" ];
    };
  };
}
