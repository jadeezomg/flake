# PT-BR subtitles for the Series-PtBr folder, with no manual steps.
#
#   Sonarr  an auto-tagging rule tags every series in /data/media/Series-PtBr
#           with "pt-br".
#   Bazarr  a "PT-BR" language profile (Portuguese (Brazil) subtitles) carries
#           the tag "pt-br", so Bazarr assigns it to those series on its next
#           Sonarr sync. Everything else keeps the English profile.
#
# Bazarr keeps language profiles in its database, not in config.yaml, so this
# unit writes them through Bazarr's API on each boot and deploy. Bazarr
# replaces the full profile list on save, so the unit sends the existing
# profiles together with PT-BR.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tag = "pt-br";
  folder = "/data/media/Series-PtBr";
  rule = "PT-BR folder";
  profile = "PT-BR";
  sonarrUrl = "http://127.0.0.1:8989/api/v3";
  bazarrUrl = "http://127.0.0.1:6767/api";

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;
  yq = lib.getExe pkgs.yq-go;
in
{
  systemd.services.media-ptbr = {
    description = "Tag PT-BR series in Sonarr and give them PT-BR subtitles in Bazarr";
    after = [
      "sonarr.service"
      "bazarr.service"
    ];
    wantedBy = [ "multi-user.target" ];
    onFailure = [ "ntfy-alert@%n.service" ];
    serviceConfig = {
      Type = "oneshot";
      # Bazarr's API key is only in its config.yaml, which belongs to unraid.
      User = "unraid";
      Group = "users";
      RuntimeDirectory = "media-ptbr";
      LoadCredential = [ "sonarr-api-key:${config.sops.secrets."mini/media/sonarr/api-key".path}" ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
    script = ''
      set -euo pipefail
      umask 077
      run=$RUNTIME_DIRECTORY
      printf 'X-Api-Key: %s\n' "$(<"$CREDENTIALS_DIRECTORY/sonarr-api-key")" >"$run/sonarr"
      printf 'X-API-KEY: %s\n' "$(${yq} '.auth.apikey' /srv/nixflix/bazarr/config/config.yaml)" >"$run/bazarr"
      sonarr() { ${curl} -sSf --max-time 30 -H @"$run/sonarr" -H "Content-Type: application/json" "$@"; }
      bazarr() { ${curl} -sSf --max-time 120 -H @"$run/bazarr" "$@"; }
      wait_for() {
        for _ in $(seq 60); do "$1" "$2" >/dev/null 2>&1 && return; sleep 2; done
        echo "$2 did not answer" >&2; return 1
      }
      wait_for sonarr ${sonarrUrl}/system/status
      wait_for bazarr ${bazarrUrl}/system/status

      # Sonarr: the tag, then the auto-tagging rule built from Sonarr's schema.
      tag_id=$(sonarr ${sonarrUrl}/tag | ${jq} -r --arg l ${tag} '.[] | select(.label == $l) | .id')
      if [ -z "$tag_id" ]; then
        tag_id=$(${jq} -n --arg l ${tag} '{label: $l}' | sonarr -X POST --data-binary @- ${sonarrUrl}/tag | ${jq} -r .id)
      fi
      payload=$(sonarr ${sonarrUrl}/autotagging/schema | ${jq} -c \
        --arg name ${lib.escapeShellArg rule} --arg folder ${folder} --argjson tag "$tag_id" '
          (map(select(.implementation == "RootFolderSpecification"))[0]
            | .name = "Series-PtBr folder" | .negate = false | .required = true
            | .fields |= map(if .name == "value" then .value = $folder else . end)) as $spec
          | {name: $name, removeTagsAutomatically: true, tags: [$tag], specifications: [$spec]}')
      rule_id=$(sonarr ${sonarrUrl}/autotagging | ${jq} -r --arg name ${lib.escapeShellArg rule} '.[] | select(.name == $name) | .id')
      if [ -n "$rule_id" ]; then
        ${jq} -c --argjson id "$rule_id" '.id = $id' <<<"$payload" \
          | sonarr -X PUT --data-binary @- "${sonarrUrl}/autotagging/$rule_id" >/dev/null
      else
        sonarr -X POST --data-binary @- ${sonarrUrl}/autotagging <<<"$payload" >/dev/null
      fi
      echo "sonarr: series in ${folder} get the tag ${tag}"

      # Bazarr: enable Portuguese (Brazil), keep the enabled languages, and
      # upsert the PT-BR profile next to the existing ones.
      profiles=$(bazarr ${bazarrUrl}/system/languages/profiles | ${jq} -c --arg name ${profile} --arg tag ${tag} '
        (map(select(.name == $name))[0].profileId // (([.[].profileId] | max // 0) + 1)) as $id
        | map(select(.name != $name))
          + [{profileId: $id, name: $name, cutoff: 1, tag: $tag, originalFormat: 0,
              mustContain: [], mustNotContain: [],
              items: [{id: 1, language: "pb", hi: false, forced: false,
                       audio_exclude: false, audio_only_include: false}]}]')
      languages=()
      for code in $(bazarr ${bazarrUrl}/system/languages | ${jq} -r '[.[] | select(.enabled) | .code2] + ["pb"] | unique | .[]'); do
        languages+=(--form-string "languages-enabled=$code")
      done
      bazarr -X POST "''${languages[@]}" --form-string "languages-profiles=$profiles" ${bazarrUrl}/system/settings >/dev/null
      echo "bazarr: profile ${profile} for series tagged ${tag}"
    '';
  };
}
