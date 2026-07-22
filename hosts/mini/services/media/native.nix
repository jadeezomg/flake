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
in
{
  services.plex = {
    enable = mediaEnabled;
    package = pkgs.plex;
    dataDir = "/srv/nixflix/plex";
    user = "unraid";
    group = "users";
    accelerationDevices = [ "/dev/dri/renderD128" ];
    openFirewall = false;
  };

  services.seerr = {
    enable = mediaEnabled;
    package = pkgs.seerr;
    configDir = "/var/lib/seerr";
    port = 5055;
    openFirewall = false;
  };

  services.bazarr = {
    enable = mediaEnabled;
    dataDir = "/srv/nixflix/bazarr";
    listenPort = 6767;
    user = "unraid";
    group = "users";
    openFirewall = false;
  };

  systemd.services = lib.mkIf mediaEnabled {
    plex = {
      after = mountDeps;
      requires = mountDeps;
      environment = {
        PLEX_MEDIA_SERVER_TMPDIR = lib.mkForce "/srv/nixflix/plex-transcode";
        TMPDIR = lib.mkForce "/srv/nixflix/plex-transcode";
      };
      unitConfig.RequiresMountsFor = [ "/media" ];
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
      preStart = ''
        install -d -m 0700 /srv/nixflix/bazarr/config
        config=/srv/nixflix/bazarr/config/config.yaml
        test -s "$config" || printf '{}\n' >"$config"

        export SONARR_API_KEY="$(<"$CREDENTIALS_DIRECTORY/sonarr-api-key")"
        export RADARR_API_KEY="$(<"$CREDENTIALS_DIRECTORY/radarr-api-key")"
        export OPENSUBTITLES_USERNAME="$(<"$CREDENTIALS_DIRECTORY/opensubtitles-username")"
        export OPENSUBTITLES_PASSWORD="$(<"$CREDENTIALS_DIRECTORY/opensubtitles-password")"
        ${pkgs.yq-go}/bin/yq -i '
          .general.enabled_providers = [
            "animetosho",
            "gestdown",
            "opensubtitlescom",
            "yifysubtitles"
          ] |
          .general.use_embedded_subs = true |
          .general.embedded_subs_show_desired = true |
          .general.parse_embedded_audio_track = true |
          .general.serie_default_enabled = true |
          .general.serie_default_profile = 1 |
          .general.movie_default_enabled = true |
          .general.movie_default_profile = 1 |
          .general.minimum_score = 85 |
          .general.minimum_score_movie = 75 |
          .general.use_sonarr = true |
          .general.use_radarr = true |
          .sonarr.ip = "127.0.0.1" |
          .sonarr.port = 8989 |
          .sonarr.ssl = false |
          .sonarr.apikey = strenv(SONARR_API_KEY) |
          .radarr.ip = "127.0.0.1" |
          .radarr.port = 7878 |
          .radarr.ssl = false |
          .radarr.apikey = strenv(RADARR_API_KEY) |
          .opensubtitlescom.username = strenv(OPENSUBTITLES_USERNAME) |
          .opensubtitlescom.password = strenv(OPENSUBTITLES_PASSWORD) |
          .opensubtitlescom.use_hash = true
        ' "$config"
        unset SONARR_API_KEY RADARR_API_KEY OPENSUBTITLES_USERNAME OPENSUBTITLES_PASSWORD
      '';
      serviceConfig = {
        BindPaths = [
          "/data/media/Series"
          "/data/media/Anime"
          "/data/media/Series-PtBr"
          "/data/media/Cinema"
        ];
        LoadCredential = [
          "sonarr-api-key:${config.sops.secrets."mini/media/sonarr/api-key".path}"
          "radarr-api-key:${config.sops.secrets."mini/media/radarr/api-key".path}"
          "opensubtitles-username:${config.sops.secrets."mini/media/bazarr/opensubtitles-username".path}"
          "opensubtitles-password:${config.sops.secrets."mini/media/bazarr/opensubtitles-password".path}"
        ];
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/srv/nixflix/bazarr"
          "/data/media/Series"
          "/data/media/Anime"
          "/data/media/Series-PtBr"
          "/data/media/Cinema"
        ];
      };
    };

    bazarr-english-profile = {
      description = "Reconcile Bazarr English subtitle profile";
      wantedBy = [ "multi-user.target" ];
      after = [ "bazarr.service" ];
      requires = [ "bazarr.service" ];
      path = [ pkgs.coreutils ];
      script = ''
        api=http://127.0.0.1:6767/api
        config=/srv/nixflix/bazarr/config/config.yaml
        for _ in $(seq 1 60); do
          api_key="$(${pkgs.yq-go}/bin/yq -r '.auth.apikey // ""' "$config")"
          if test -n "$api_key" && ${pkgs.curl}/bin/curl -fsS -H "X-API-KEY: $api_key" "$api/system/status" >/dev/null; then
            break
          fi
          sleep 1
        done
        test -n "$api_key"

        profile="$(${pkgs.jq}/bin/jq -cn '{
          profileId: 1,
          name: "English",
          cutoff: 1,
          items: [{
            id: 1,
            language: "en",
            hi: false,
            forced: false,
            audio_exclude: false,
            audio_only_include: false
          }],
          mustContain: [],
          mustNotContain: [],
          originalFormat: false,
          tag: null
        }')"
        ${pkgs.curl}/bin/curl -fsS -X POST           -H "X-API-KEY: $api_key"           --data-urlencode "languages-enabled=en"           --data-urlencode "languages-profiles=[$profile]"           "$api/system/settings" >/dev/null

        for media_type in series movies; do
          case "$media_type" in
            series)
              json_id_field=sonarrSeriesId
              form_id_field=seriesid
              ;;
            movies)
              json_id_field=radarrId
              form_id_field=radarrid
              ;;
          esac
          mapfile -t ids < <(
            ${pkgs.curl}/bin/curl -fsS -H "X-API-KEY: $api_key" "$api/$media_type" |
              ${pkgs.jq}/bin/jq -r --arg field "$json_id_field" '.data[] | select(.profileId != 1) | .[$field]'
          )
          if test "''${#ids[@]}" -gt 0; then
            args=()
            for id in "''${ids[@]}"; do
              args+=(--data-urlencode "$form_id_field=$id" --data-urlencode "profileid=1")
            done
            ${pkgs.curl}/bin/curl -fsS -X POST -H "X-API-KEY: $api_key"               "''${args[@]}" "$api/$media_type" >/dev/null
          fi
        done

        ${pkgs.curl}/bin/curl -fsS -H "X-API-KEY: $api_key" "$api/system/languages/profiles" |
          ${pkgs.jq}/bin/jq -e 'any(.[]; .profileId == 1 and .name == "English")' >/dev/null
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "unraid";
        Group = "users";
      };
    };

    seerr.environment.HOST = "127.0.0.1";
  };

  systemd.tmpfiles.rules = lib.mkIf mediaEnabled [
    "d /srv/nixflix/plex-transcode 0755 unraid users -"
  ];

  # Mini currently uses the iptables-backed NixOS firewall. Keep these
  # discovery rules IPv4-only rather than opening Plex on the global IPv6 address.
  networking.firewall = lib.mkIf mediaEnabled {
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
