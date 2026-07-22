{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./common.nix) mediaEnabled mountDeps;

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
        # Sonarr/Radarr removeCompletedDownloads only deletes torrents after seeding
        # goals are met. Ratio 0 + Stop marks them done immediately after download so
        # Arr can import (hardlink) then remove the torrent job (files kept).
        BitTorrent.Session = {
          GlobalMaxRatio = 0;
          ShareLimitAction = "Stop";
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
  };

  # Drop leftover host-netns setuid helper from earlier revisions.
  system.activationScripts.qbittorrentSearchCleanup = lib.mkIf mediaEnabled ''
    rm -f /var/lib/qBittorrent/bin/qbittorrent-search-netns \
      /var/lib/qBittorrent/bin/python3
  '';

  systemd.tmpfiles.settings = lib.mkIf mediaEnabled {
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
    qbittorrent.serviceConfig = {
      ProtectSystem = lib.mkForce "strict";
      ReadWritePaths = lib.mkForce [
        "/var/lib/qBittorrent"
        "/data/torrents"
      ];
    };

    sabnzbd = {
      after = mountDeps;
      requires = mountDeps;
      serviceConfig = {
        # Avoid BindPaths (can remount NFS read-only). Keep one RW view of /data.
        BindPaths = lib.mkForce [ ];
        ReadWritePaths = lib.mkForce [
          "/var/lib/sabnzbd"
          "/data"
        ];
      };
    };
  };
}
