{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./common.nix) mountDeps;

  # SABnzbd's queue/history database and logs stay on mini's SSD. On the data
  # share the mover put them on an array disk (disk2), and SABnzbd writes the
  # database every few seconds, so disk2 and parity never spun down.
  sabnzbdState = "/var/lib/sabnzbd";

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
  qbittorrentWebuiPassword =
    pkgs.writers.writePython3 "qbittorrent-webui-password"
      {
        doCheck = false;
      }
      ''
        import base64
        import hashlib
        import os
        import pathlib
        import re
        import sys

        secret_path = pathlib.Path(sys.argv[1])
        conf_path = pathlib.Path("/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf")

        password = secret_path.read_bytes().strip()
        if not password:
            raise SystemExit("empty qbittorrent password secret")
        if not conf_path.is_file():
            raise SystemExit(
                f"missing {conf_path} (serverConfig install should run first)"
            )

        salt = os.urandom(16)
        dk = hashlib.pbkdf2_hmac("sha512", password, salt, 100_000, dklen=64)
        value = (
            "@ByteArray("
            + base64.b64encode(salt).decode()
            + ":"
            + base64.b64encode(dk).decode()
            + ")"
        )

        text = conf_path.read_text()
        line = f'WebUI\\Password_PBKDF2="{value}"'
        pattern = re.compile(r"^WebUI\\Password_PBKDF2=.*$", re.M)
        # Callable replacements: line has backslashes that re.sub would re-parse.
        if pattern.search(text):
            text = pattern.sub(lambda _m: line, text, count=1)
        elif re.search(r"^\[Preferences\]\s*$", text, re.M):
            text = re.sub(
                r"^(\[Preferences\]\s*)$",
                lambda m: m.group(1) + "\n" + line,
                text,
                count=1,
                flags=re.M,
            )
        else:
            text = text.rstrip() + "\n[Preferences]\n" + line + "\n"
        conf_path.write_text(text)
      '';

  # Torrents from qBittorrent's own search (or added by hand in the WebUI)
  # have no category: Sonarr, Radarr, Lidarr and Prowlarr always set one.
  # When such a torrent uses a sukebei tracker, this gives it the category
  # `jav` (its own folder, see `categories`) and the tag `sukebei`.
  # qBittorrent runs it for every new torrent (AutoRun.OnTorrentAdded) and
  # passes the info hash and the category. The WebUI password comes from the
  # unit's credentials, which qBittorrent's child processes inherit.
  qbittorrent = config.nixflix.torrentClients.qbittorrent;
  # Plain values, not read back from serverConfig: the script path is part
  # of serverConfig, so reading the username from it is a cycle.
  # connectionAddress reads serverConfig too.
  webuiUsername = "admin";
  # The WebUI listens only on the namespace address (nixflix's default for
  # WebUI.Address), not on loopback. With 127.0.0.1 the login got
  # "connection refused" and no torrent was ever tagged (2026-10-26).
  webuiAddress = config.vpnNamespaces.${config.nixflix.vpn.namespace}.namespaceAddress;
  qbittorrentTagSukebei = pkgs.writeShellApplication {
    name = "qbittorrent-tag-sukebei";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      hash=$1
      category=''${2:-}
      [ -z "$category" ] || exit 0

      api=http://${webuiAddress}:${toString qbittorrent.webuiPort}/api/v2
      # `|| true`: a failed curl must reach the log line below. Without it,
      # errexit ended the script with no trace in the journal.
      cookie=$(curl -sS --max-time 10 -D - -o /dev/null \
        --data-urlencode "username=${webuiUsername}" \
        --data-urlencode "password@$CREDENTIALS_DIRECTORY/webui-password" \
        "$api/auth/login" | sed -n 's/^[Ss]et-[Cc]ookie: \(\(QBT_\)\{0,1\}SID[_0-9]*=[^;]*\).*/\1/p' || true)
      if [ -z "$cookie" ]; then
        logger -t qbittorrent-tag-sukebei "WebUI login failed, $hash not tagged"
        exit 1
      fi
      qbt() { curl -fsS --max-time 10 -b "$cookie" "$@"; }
      trap 'qbt -X POST "$api/auth/logout" >/dev/null || true' EXIT

      # The torrent can take a moment to appear in the API.
      for _ in 1 2 3 4 5; do
        trackers=$(qbt "$api/torrents/trackers?hash=$hash" || true)
        [ -n "$trackers" ] && break
        sleep 1
      done
      if jq -e 'any(.[]; .url | test("sukebei"))' <<<"$trackers" >/dev/null 2>&1; then
        if qbt --data "hashes=$hash&category=jav" "$api/torrents/setCategory" &&
          qbt --data "hashes=$hash&tags=sukebei" "$api/torrents/addTags"; then
          logger -t qbittorrent-tag-sukebei "$hash: category jav, tag sukebei"
        else
          logger -t qbittorrent-tag-sukebei "$hash: setting category or tag failed"
          exit 1
        fi
      fi
    '';
  };

  qbittorrentWebuiPasswordScript = pkgs.writeShellScript "qbittorrent-webui-password-from-sops" ''
    set -euo pipefail
    secret=${config.sops.secrets."mini/media/qbittorrent/password".path}
    if [ ! -r "$secret" ]; then
      echo "qbittorrent-webui-password: cannot read $secret" >&2
      exit 1
    fi
    # writePython3 returns the script path (symlink), not a package with /bin/.
    exec ${qbittorrentWebuiPassword} "$secret"
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
        # Set by qbittorrent-tag-sukebei. Under /data/torrents, so the Mover
        # Tuning skiplist keeps it on the SSD.
        jav = "/data/torrents/jav";
      };
      serverConfig = {
        Network.Proxy.Profiles = {
          Misc = false;
          RSS = false;
        };
        # qBittorrent's own UPnP / NAT-PMP is off, as Proton's guide says.
        # qbittorrent-port-forward (../port-forward.nix) gets the port.
        Network.PortForwardingEnabled = false;
        BitTorrent.Session = {
          GlobalMaxRatio = 0;
          ShareLimitAction = "Stop";
          MaxActiveDownloads = 19;
          MaxActiveUploads = 1;
          MaxActiveTorrents = 20;
          IgnoreSlowTorrentsForQueueing = true;

          # Keep partial torrents in their own directory, away from the finished
          # files. Two reasons, in order of importance:
          #
          #   1. The Unraid mover must not move a file while mini is still
          #      writing it over NFS: the write then lands on an unlinked inode
          #      and the download is silently corrupted. The Mover Tuning skip
          #      list (/boot/config/plugins/ca.mover.tuning/skiplist.txt on
          #      jadee-server) holds /mnt/array_cache/data/torrents and
          #      /mnt/array_cache/data/usenet, so downloads never leave the SSD.
          #   2. Only finished files reach the array, so the array disks stay
          #      spun down during a download.
          #
          # qBittorrent keeps the category subfolder under this path, so the
          # per-category layout above still applies while downloading.
          TempPathEnabled = true;
          TempPath = "/data/torrents/incomplete";
        };
        AutoRun.OnTorrentAdded = {
          Enabled = true;
          # %I info hash, %L category. No quotes: QSettings strips them, and
          # neither value contains a space.
          Program = "${lib.getExe qbittorrentTagSukebei} %I %L";
        };
        Preferences = {
          WebUI = {
            # Non-secret; Password_PBKDF2 is injected from sops plaintext in ExecStartPre.
            Username = webuiUsername;
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
          admin_dir = "${sabnzbdState}/admin";
          log_dir = "${sabnzbdState}/logs";
          # nixflix turns this on. It asks the server for every article of a
          # job before the download starts, one job at a time, so a full
          # queue sat in "Checking" for hours (2026-10-26). fast_fail and
          # fail_hopeless_jobs (both on) already stop a job that cannot
          # complete.
          pre_check = false;
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
      enable = true;
      wgConfFile = config.sops.secrets."mini/media/vpn/wireguard-conf".path;
      accessibleFrom = [
        "192.168.178.0/24"
        "100.64.0.0/10"
      ];
    };
  };

  system.activationScripts.qbittorrentSearchCleanup = ''
    rm -f /var/lib/qBittorrent/bin/qbittorrent-search-netns \
      /var/lib/qBittorrent/bin/python3
  '';

  systemd.tmpfiles.settings = {
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

  systemd.services = {
    # One ReadWritePaths entry for /data (not /data/torrents). Separate systemd
    # binds of NFS subdirs remount RO under ProtectSystem=strict — same fix as Arr.
    qbittorrent = {
      after = mountDeps;
      requires = mountDeps;
      serviceConfig = {
        ProtectSystem = lib.mkForce "strict";
        ReadWritePaths = lib.mkForce [
          "/var/lib/qBittorrent"
          "/data"
        ];
        # '+' = root so we can read root-only sops; runs after nixpkgs conf install.
        ExecStartPre = lib.mkAfter [ "+${qbittorrentWebuiPasswordScript}" ];
        # For qbittorrent-tag-sukebei, which logs in to the WebUI API.
        LoadCredential = [
          "webui-password:${config.sops.secrets."mini/media/qbittorrent/password".path}"
        ];
      };
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
