# Seerr request settings, owned by Nix. Seerr is Plex-backed (services.seerr in
# native.nix), so nixflix.seerr does not fit. Seerr has no config option for
# these values, so preStart merges them into settings.json before each start.
# Seerr creates settings.json on its first start; until then this is a no-op.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Default request profile in Radarr and Sonarr (nixflix/quality.nix). Its ID
  # changes when Recyclarr recreates it, so preStart finds the ID by name.
  defaultProfile = "Original + EN Subs";

  patch = pkgs.writeText "seerr-settings-patch.json" (
    builtins.toJSON {
      main = {
        # Season picker on TV requests.
        partialRequestsEnabled = true;
        # Specials (season 0) in the request dialog.
        enableSpecialEpisodes = true;
      };
      # TVDB splits anime cours into seasons; TMDB often merges them.
      metadataSettings = {
        tv = "tvdb";
        anime = "tvdb";
      };
    }
  );

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;
in
{
  sops.secrets."mini/media/seerr/api-key".restartUnits = [ "seerr.service" ];

  systemd.services.seerr = {
    # Profiles are synced and old ones deleted before Seerr reads their IDs.
    after = [
      "radarr.service"
      "sonarr.service"
      "recyclarr.service"
      "recyclarr-cleanup-profiles.service"
    ];

    serviceConfig.LoadCredential = [
      "radarr-api-key:${config.sops.secrets."mini/media/radarr/api-key".path}"
      "sonarr-api-key:${config.sops.secrets."mini/media/sonarr/api-key".path}"
      "seerr-api-key:${config.sops.secrets."mini/media/seerr/api-key".path}"
    ];

    preStart = ''
      settings=/var/lib/seerr/settings.json
      [ -s "$settings" ] || exit 0

      # Prints {activeProfileId, activeProfileName}, or {} when the service
      # is down or the profile is missing. Then Seerr keeps its old value.
      profile() {
        local key profiles
        key=$(<"$CREDENTIALS_DIRECTORY/$1-api-key")
        for _ in $(seq 30); do
          if profiles=$(${curl} -sf --max-time 5 -H "X-Api-Key: $key" \
            "http://127.0.0.1:$2/api/v3/qualityprofile"); then
            ${jq} -c --arg name ${lib.escapeShellArg defaultProfile} \
              'map(select(.name == $name))[0]
                | if . then {activeProfileId: .id, activeProfileName: .name} else {} end' \
              <<<"$profiles"
            return
          fi
          sleep 1
        done
        echo '{}'
      }

      radarr=$(profile radarr 7878)
      sonarr=$(profile sonarr 8989)
      # Seerr's own API key comes from sops, so Homepage can read it too.
      # Seerr keeps a key that is already in settings.json.
      ${jq} \
        --slurpfile patch ${patch} \
        --argjson radarr "$radarr" \
        --argjson sonarr "$sonarr" \
        --rawfile apikey "$CREDENTIALS_DIRECTORY/seerr-api-key" \
        '. * $patch[0]
          | .main.apiKey = $apikey
          | .radarr |= map(. + $radarr)
          | .sonarr |= map(. + $sonarr)' \
        "$settings" >"$settings.tmp"
      mv "$settings.tmp" "$settings"
    '';
  };
}
