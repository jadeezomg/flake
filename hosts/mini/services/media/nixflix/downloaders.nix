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

  # nixflix password._secret is Arr→qBittorrent only; WebUI needs Password_PBKDF2.
  # Derive the hash at start from the same sops plaintext so the flake never stores it.
  qbittorrentPbkdf2Py = pkgs.writeText "qbittorrent-pbkdf2.py" ''
    import base64
    import hashlib
    import os
    import sys

    password = open(sys.argv[1], "rb").read().strip()
    if not password:
        raise SystemExit("empty qbittorrent password secret")
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha512", password, salt, 100_000, dklen=64)
    print(
        "@ByteArray("
        + base64.b64encode(salt).decode()
        + ":"
        + base64.b64encode(dk).decode()
        + ")"
    )
  '';

  qbittorrentPatchConfPy = pkgs.writeText "qbittorrent-patch-webui-password.py" ''
    import pathlib
    import re
    import sys

    conf = pathlib.Path(sys.argv[1])
    value = sys.argv[2]
    text = conf.read_text()
    line = f'WebUI\\Password_PBKDF2="{value}"'
    pattern = re.compile(r"^WebUI\\Password_PBKDF2=.*$", re.M)
    if pattern.search(text):
        text = pattern.sub(line, text, count=1)
    elif re.search(r"^\[Preferences\]\s*$", text, re.M):
        text = re.sub(
            r"^(\[Preferences\]\s*)$",
            r"\1\n" + line,
            text,
            count=1,
            flags=re.M,
        )
    else:
        text = text.rstrip() + "\n[Preferences]\n" + line + "\n"
    conf.write_text(text)
  '';

  qbittorrentWebuiPasswordScript = pkgs.writeShellScript "qbittorrent-webui-password-from-sops" ''
    set -euo pipefail
    conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
    secret=${config.sops.secrets."mini/media/qbittorrent/password".path}
    if [ ! -r "$secret" ]; then
      echo "qbittorrent-webui-password: cannot read $secret" >&2
      exit 1
    fi
    if [ ! -f "$conf" ]; then
      echo "qbittorrent-webui-password: missing $conf (serverConfig install should run first)" >&2
      exit 1
    fi
    hash="$(${pkgs.python3}/bin/python3 ${qbittorrentPbkdf2Py} "$secret")"
    ${pkgs.python3}/bin/python3 ${qbittorrentPatchConfPy} "$conf" "$hash"
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
        Network.Proxy.Profiles = {
          Misc = false;
          RSS = false;
        };
        BitTorrent.Session = {
          GlobalMaxRatio = 0;
          ShareLimitAction = "Stop";
        };
        Preferences = {
          WebUI = {
            # Non-secret; Password_PBKDF2 is injected from sops plaintext in ExecStartPre.
            Username = "admin";
          };
          Search = {
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
      # '+' = root so we can read root-only sops; runs after nixpkgs conf install.
      ExecStartPre = lib.mkAfter [ "+${qbittorrentWebuiPasswordScript}" ];
    };

    sabnzbd = {
      after = mountDeps;
      requires = mountDeps;
      serviceConfig = {
        BindPaths = lib.mkForce [ ];
        ReadWritePaths = lib.mkForce [
          "/var/lib/sabnzbd"
          "/data"
        ];
      };
    };
  };
}
