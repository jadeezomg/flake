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

  # Dedicated interpreter for qBittorrent search plugins (not system python3).
  qbittorrentSearchPython = pkgs.python3.withPackages (
    ps: with ps; [
      beautifulsoup4
      defusedxml
      html5lib
      lxml
      requests
    ]
  );
  qbittorrentNovaDir = "/var/lib/qBittorrent/qBittorrent/data/nova3";

  # Search plugin enable-list lives in sops: mini/media/qbittorrent/search-plugins (JSON).
  # official: names in qbittorrent/search-plugins nova3/engines at qbittorrentSearchPluginsRev.
  # external: unofficial plugins catalogued in search-plugins wiki (fetched at build time, not vendored).
  qbittorrentSearchPluginsRev = "62f296ed47010ab0ea9dbd43257a1a20025d1d1a";

  qbittorrentOfficialSearchPlugins = pkgs.fetchFromGitHub {
    owner = "qbittorrent";
    repo = "search-plugins";
    rev = qbittorrentSearchPluginsRev;
    hash = "sha256-ncY7iK6lTIbF3h1Ts+BC2YHT8sWX4XRSi3vbORSQoMw=";
  };

  qbittorrentOfficialSearchPluginsDir = "${qbittorrentOfficialSearchPlugins}/nova3/engines";

  # https://github.com/qbittorrent/search-plugins/wiki/Unofficial-search-plugins
  qbittorrentExternalSearchPlugins = {
    sukebeisi = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/vt-idiot/qBit-SukebeiNyaa-plugin/master/engines/sukebeisi.py";
      hash = "sha256-NTy4igWjf2yjD5zjYWPWSSbIcGpaQb72NOS04HsVVTk=";
    };
  };

  qbittorrentExternalSearchPluginsDir = pkgs.linkFarm "qbittorrent-external-search-plugins" (
    lib.mapAttrsToList (name: path: {
      inherit name path;
    }) qbittorrentExternalSearchPlugins
  );

  qbittorrentSearchPluginsSync = pkgs.writeShellScript "qbittorrent-search-plugins-sync" ''
    set -euo pipefail
    config_file="''${QBITTORRENT_SEARCH_PLUGINS_CONFIG:?QBITTORRENT_SEARCH_PLUGINS_CONFIG is unset}"
    official_src="${qbittorrentOfficialSearchPluginsDir}"
    external_src="${qbittorrentExternalSearchPluginsDir}"
    dst="${qbittorrentNovaDir}/engines"
    jq=${pkgs.jq}/bin/jq

    if [ ! -r "$config_file" ]; then
      echo "qbittorrent-search-plugins-sync: cannot read $config_file" >&2
      exit 1
    fi

    install -d -m 0755 -o qbittorrent -g users "$dst"

    # Drop stale plugins so sops edits take effect without manual cleanup.
    find "$dst" -maxdepth 1 -name '*.py' ! -name '__init__.py' -delete

    mapfile -t official < <("$jq" -r '.official[]? // empty' "$config_file")
    mapfile -t external < <("$jq" -r '.external[]? // empty' "$config_file")

    if [ ''${#official[@]} -eq 0 ] && [ ''${#external[@]} -eq 0 ]; then
      echo "qbittorrent-search-plugins-sync: no plugins in $config_file (need .official and/or .external arrays)" >&2
      exit 1
    fi

    for name in "''${official[@]}"; do
      plugin="$official_src/$name.py"
      if [ ! -e "$plugin" ]; then
        echo "qbittorrent-search-plugins-sync: unknown official plugin '$name' (not in search-plugins@${qbittorrentSearchPluginsRev})" >&2
        exit 1
      fi
      install -m 0644 -o qbittorrent -g users "$plugin" "$dst/"
    done

    for name in "''${external[@]}"; do
      plugin="$external_src/$name"
      if [ ! -e "$plugin" ]; then
        echo "qbittorrent-search-plugins-sync: unknown external plugin '$name' (not in qbittorrentExternalSearchPlugins)" >&2
        exit 1
      fi
      install -m 0644 -o qbittorrent -g users "$plugin" "$dst/$name.py"
    done

    if [ ! -e "$dst/__init__.py" ]; then
      install -m 0644 -o qbittorrent -g users /dev/null "$dst/__init__.py"
    fi
  '';

  # qBittorrent's configured interpreter (non-setuid launcher → setuid netns helper).
  qbittorrentSearchPythonPath = "/var/lib/qBittorrent/bin/python3";
  qbittorrentSearchNetnsPath = "/var/lib/qBittorrent/bin/qbittorrent-search-netns";

  qbittorrentSearchPythonLauncher = pkgs.writeShellScript "qbittorrent-search-python-launcher" ''
    exec ${qbittorrentSearchNetnsPath} "$@"
  '';

  # setuid helper: only qbittorrent may invoke; nsenter host netns, drop privs, run python.
  # Strips qBittorrent's -I (breaks PYTHONPATH / nova3 `helpers` imports).
  qbittorrentSearchNetnsHelper = pkgs.runCommand "qbittorrent-search-netns-helper" { } ''
    mkdir -p $out/bin
    cat > main.c <<EOF
    #include <pwd.h>
    #include <stdio.h>
    #include <string.h>
    #include <stdlib.h>
    #include <unistd.h>

    static void die(const char *msg) {
      perror(msg);
      _exit(1);
    }

    int main(int argc, char **argv) {
      struct passwd *pw = getpwnam("qbittorrent");
      if (!pw || getuid() != pw->pw_uid) {
        fprintf(stderr, "qbittorrent-search-netns: refused caller uid %d\n", getuid());
        return 1;
      }

      char uidbuf[32], gidbuf[32];
      snprintf(uidbuf, sizeof uidbuf, "%ld", (long)pw->pw_uid);
      snprintf(gidbuf, sizeof gidbuf, "%ld", (long)pw->pw_gid);

      /* nsenter argv + python + filtered user args (skip -I) + NULL */
      char **child = calloc((size_t)argc + 12, sizeof(char *));
      if (!child) die("calloc");
      int n = 0;
      child[n++] = "nsenter";
      child[n++] = "-t";
      child[n++] = "1";
      child[n++] = "-n";
      child[n++] = "-S";
      child[n++] = uidbuf;
      child[n++] = "-G";
      child[n++] = gidbuf;
      child[n++] = "--";
      child[n++] = (char *)"${qbittorrentSearchPython}/bin/python3";
      for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-I") == 0) continue;
        child[n++] = argv[i];
      }
      child[n] = NULL;

      if (seteuid(0) != 0) die("seteuid");
      if (setenv("PYTHONPATH", "${qbittorrentNovaDir}", 1) != 0) die("setenv PYTHONPATH");
      if (setenv("SSL_CERT_FILE", "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt", 1) != 0) die("setenv SSL_CERT_FILE");
      if (chdir("${qbittorrentNovaDir}/engines") != 0) die("chdir");
      execv("${pkgs.util-linux}/bin/nsenter", child);
      die("execv");
    }
    EOF
    ${pkgs.gcc}/bin/cc -O2 -o $out/bin/qbittorrent-search-python main.c
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
            pythonExecutablePath = qbittorrentSearchPythonPath;
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

  # tmpfiles type C does not refresh an existing setuid copy after rebuilds.
  system.activationScripts.qbittorrentSearchPythonHelper = lib.mkIf mediaEnabled ''
    install -m 4755 -o root -g root \
      ${qbittorrentSearchNetnsHelper}/bin/qbittorrent-search-python \
      ${qbittorrentSearchNetnsPath}
    install -m 0755 -o qbittorrent -g users \
      ${qbittorrentSearchPythonLauncher} \
      ${qbittorrentSearchPythonPath}
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
      "/var/lib/qBittorrent/bin".d = {
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
    qbittorrent = {
      path = [
        qbittorrentSearchPython
        pkgs.jq
        pkgs.util-linux
      ];
      preStart = lib.mkOrder 50 ''
        export QBITTORRENT_SEARCH_PLUGINS_CONFIG=${
          config.sops.secrets."mini/media/qbittorrent/search-plugins".path
        }
        ${qbittorrentSearchPluginsSync}
      '';
      serviceConfig = {
        ProtectSystem = lib.mkForce "strict";
        # setuid nsenter helper (host netns for search); PrivateUsers/SUID hardening blocks it.
        PrivateUsers = lib.mkForce false;
        RestrictSUIDSGID = lib.mkForce false;
        NoNewPrivileges = lib.mkForce false;
        ReadWritePaths = lib.mkForce [
          "/var/lib/qBittorrent"
          "/data/torrents"
        ];
      };
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
