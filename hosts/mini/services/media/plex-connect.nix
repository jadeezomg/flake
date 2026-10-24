# Radarr/Sonarr "Connect" entry for Plex: after each import, upgrade, rename,
# or delete, Plex refreshes the affected folder. Plex cannot watch the NFS
# library for changes, so without this it waits for its scheduled scan.
#
# nixflix.notif only reads apiKey/username/password/accessToken from secret
# files, and the Plex token field is authToken. This unit therefore upserts
# the entry itself, with the token from sops via LoadCredential.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "Plex";

  # Arr apps see /data/media/...; Plex sees the same files under /media/...
  fields = {
    host = "127.0.0.1";
    port = 32400;
    useSsl = false;
    updateLibrary = true;
    mapFrom = "/data/media/";
    mapTo = "/media/";
  };

  # Events that make Plex refresh. Each is set only where the service
  # supports it (supportsOn<Event> in the schema).
  events = [
    "onDownload"
    "onUpgrade"
    "onImportComplete"
    "onRename"
    "onMovieDelete"
    "onMovieFileDelete"
    "onMovieFileDeleteForUpgrade"
    "onSeriesDelete"
    "onEpisodeFileDelete"
    "onEpisodeFileDeleteForUpgrade"
  ];

  services = {
    radarr = 7878;
    sonarr = 8989;
  };

  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;
in
{
  sops.secrets."mini/media/plex/token" = { };

  systemd.services.plex-connect = {
    description = "Configure the Plex connection in Radarr and Sonarr";
    after = [
      "plex.service"
      "radarr-config.service"
      "sonarr-config.service"
    ];
    requires = [
      "radarr-config.service"
      "sonarr-config.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      DynamicUser = true;
      LoadCredential = [
        "plex-token:${config.sops.secrets."mini/media/plex/token".path}"
      ]
      ++ lib.mapAttrsToList (
        service: _: "${service}-api-key:${config.sops.secrets."mini/media/${service}/api-key".path}"
      ) services;
    };

    script = ''
      set -euo pipefail

      connect() {
        local service=$1 port=$2 key base existing payload method url
        key=$(<"$CREDENTIALS_DIRECTORY/$service-api-key")
        base="http://127.0.0.1:$port/api/v3"
        api() { ${curl} -sSf --max-time 30 -H "X-Api-Key: $key" -H "Content-Type: application/json" "$@"; }

        existing=$(api "$base/notification" | ${jq} -c --arg name ${lib.escapeShellArg name} \
          'map(select(.name == $name))[0] // empty')
        payload=$(api "$base/notification/schema" | ${jq} -c \
          --arg name ${lib.escapeShellArg name} \
          --rawfile token "$CREDENTIALS_DIRECTORY/plex-token" \
          --argjson fields ${lib.escapeShellArg (builtins.toJSON fields)} \
          --argjson events ${lib.escapeShellArg (builtins.toJSON events)} \
          --argjson existing "''${existing:-null}" '
            map(select(.implementation == "PlexServer"))[0]
            | .name = $name
            | .tags = []
            | reduce $events[] as $e (.;
                if has($e) then .[$e] = (.["supports" + ($e | .[0:1] | ascii_upcase) + ($e | .[1:])] // false)
                else . end)
            | .fields |= map(
                .name as $n
                | if $n == "authToken" then .value = ($token | rtrimstr("\n"))
                  elif $fields | has($n) then .value = $fields[$n]
                  else . end)
            | if $existing then .id = $existing.id else . end')

        if [ -n "$existing" ]; then
          method=PUT; url="$base/notification/$(${jq} -r .id <<<"$existing")"
        else
          method=POST; url="$base/notification"
        fi
        # stdin, so the token is not on a command line.
        api -X "$method" --data-binary @- "$url" <<<"$payload" >/dev/null
        echo "$service: $method Plex connection"
      }

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (service: port: "connect ${service} ${toString port}") services
      )}
    '';
  };
}
