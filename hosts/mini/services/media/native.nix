{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./nixflix/common.nix) mountDeps;
in
{
  services = {
    plex = {
      enable = true;
      package = pkgs.plex;
      dataDir = "/srv/nixflix/plex";
      user = "unraid";
      group = "users";
      accelerationDevices = [ "/dev/dri/renderD128" ];
      openFirewall = false;
    };

    seerr = {
      enable = true;
      package = pkgs.seerr;
      configDir = "/var/lib/seerr";
      port = 5055;
      openFirewall = false;
    };

    bazarr = {
      enable = true;
      dataDir = "/srv/nixflix/bazarr";
      # Exported as DYNACONF_* variables at start. They override config.yaml,
      # so edits to these keys in the web UI do not persist.
      settings =
        let
          secret = name: { _secret = config.sops.secrets."mini/media/${name}".path; };
        in
        {
          general = {
            port = 6767;
            enabled_providers = [
              "animetosho"
              "gestdown"
              "opensubtitlescom"
              "yifysubtitles"
            ];
            use_embedded_subs = true;
            embedded_subs_show_desired = true;
            parse_embedded_audio_track = true;
            # English defaults for new Sonarr/Radarr items (language profile 1).
            # Language profiles live in the Bazarr database: define profile 1
            # in the UI once. PT-BR needs a second profile and path defaults for
            # Series-PtBr, so do not force everything to profile 1.
            serie_default_enabled = true;
            serie_default_profile = 1;
            movie_default_enabled = true;
            movie_default_profile = 1;
            minimum_score = 85;
            minimum_score_movie = 75;
            use_sonarr = true;
            use_radarr = true;
          };
          sonarr = {
            ip = "127.0.0.1";
            port = 8989;
            ssl = false;
            apikey = secret "sonarr/api-key";
          };
          radarr = {
            ip = "127.0.0.1";
            port = 7878;
            ssl = false;
            apikey = secret "radarr/api-key";
          };
          opensubtitlescom = {
            username = secret "bazarr/opensubtitles-username";
            password = secret "bazarr/opensubtitles-password";
            use_hash = true;
          };
        };
      user = "unraid";
      group = "users";
      openFirewall = false;
    };
  };

  systemd = {
    services = {
      plex = {
        after = mountDeps;
        requires = mountDeps;
        environment = {
          PLEX_MEDIA_SERVER_TMPDIR = lib.mkForce "/srv/nixflix/plex-transcode";
          TMPDIR = lib.mkForce "/srv/nixflix/plex-transcode";
        };
        unitConfig.RequiresMountsFor = [ "/media" ];
        # Keep stock plex ExecStartPre (!plex-run-prestart). This only adds a user
        # preStart so migrated Codec trees that lost +x get fixed before PMS starts.
        # Without execute bits, eac3_eae loops: "EAE timeout! EAE not running…".
        preStart = ''
          codecs="${config.services.plex.dataDir}/Plex Media Server/Codecs"
          if [ -d "$codecs" ]; then
            find "$codecs" -type f \( -name EasyAudioEncoder -o -name '*.so' \) -exec chmod a+x {} +
          fi
        '';
        serviceConfig = {
          # NixOS enables MemoryDenyWriteExecute on Plex; EasyAudioEncoder (EAC3/DTS)
          # needs executable pages or transcoding loops with "EAE timeout" in logs.
          MemoryDenyWriteExecute = lib.mkForce false;
          ReadWritePaths = [
            "/srv/nixflix/plex"
            "/srv/nixflix/plex-transcode"
          ];
          ReadOnlyPaths = [ "/media" ];
          InaccessiblePaths = [ "/data" ];
        };
      };

      bazarr = {
        after = mountDeps;
        requires = mountDeps;
        serviceConfig = {
          BindPaths = [
            "/data/media/Series"
            "/data/media/Anime"
            "/data/media/Series-PtBr"
            "/data/media/Cinema"
          ];
          # The nixpkgs module hardens Bazarr (PrivateTmp = "disconnected" and
          # more). It sets ProtectSystem = "full"; "strict" is stricter and
          # works with the ReadWritePaths below.
          ProtectSystem = lib.mkForce "strict";
          ReadWritePaths = [
            "/srv/nixflix/bazarr"
            "/data/media/Series"
            "/data/media/Anime"
            "/data/media/Series-PtBr"
            "/data/media/Cinema"
          ];
        };
      };

      seerr.environment.HOST = "127.0.0.1";
    };

    tmpfiles.rules = [
      "d /srv/nixflix/plex-transcode 0755 unraid users -"
    ];
  };

  # Mini currently uses the iptables-backed NixOS firewall. Keep these
  # discovery rules IPv4-only rather than opening Plex on the global IPv6 address.
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -i enp2s0f0np0 -p tcp --dport 32400 -j nixos-fw-accept
      iptables -I nixos-fw 1 -i enp2s0f0np0 -s 192.168.178.0/24 -p tcp -m multiport --dports 3005,8324,32469 -j nixos-fw-accept
      iptables -I nixos-fw 1 -i enp2s0f0np0 -s 192.168.178.0/24 -p udp -m multiport --dports 1900,5353,32410,32412,32413,32414 -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -i enp2s0f0np0 -p tcp --dport 32400 -j nixos-fw-accept || true
      iptables -D nixos-fw -i enp2s0f0np0 -s 192.168.178.0/24 -p tcp -m multiport --dports 3005,8324,32469 -j nixos-fw-accept || true
      iptables -D nixos-fw -i enp2s0f0np0 -s 192.168.178.0/24 -p udp -m multiport --dports 1900,5353,32410,32412,32413,32414 -j nixos-fw-accept || true
    '';
  };
}
