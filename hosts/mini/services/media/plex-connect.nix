# Radarr/Sonarr "Connect" entry for Plex: after each import, upgrade, rename,
# or delete, Plex refreshes the affected folder. Plex cannot watch the NFS
# library for changes, so without this it waits for its scheduled scan.
#
# nixflix.notif only reads apiKey/username/password/accessToken from secret
# files. The Plex token field is authToken, so through nixflix the token would
# land in the world-readable Nix store. This unit therefore upserts the entry
# itself, with the token from sops via LoadCredential.
#
# nixflix's <service>-notifications units delete every connection they do not
# manage, Plex included. This unit runs after them and is PartOf them, so each
# time nixflix reconciles, it adds Plex back a few seconds later.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "Plex";

  fields = {
    host = "127.0.0.1";
    port = 32400;
    useSsl = false;
    updateLibrary = true;
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
    "onReleaseImport"
    "onAlbumDelete"
    "onArtistDelete"
    "onTrackRetag"
  ];

  # Each app sees the files under its own path; Plex sees them under /media.
  services = {
    radarr = {
      port = 7878;
      api = "v3";
      mapFrom = "/data/media/";
      mapTo = "/media/";
    };
    sonarr = {
      port = 8989;
      api = "v3";
      mapFrom = "/data/media/";
      mapTo = "/media/";
    };
    lidarr = {
      port = 8686;
      api = "v1";
      mapFrom = "/Music/";
      mapTo = "/media/Music/";
    };
  };
  notifications = lib.mapAttrsToList (service: _: "${service}-notifications.service") services;

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
    ]
    ++ notifications;
    requires = [
      "radarr-config.service"
      "sonarr-config.service"
    ];
    # Restarts with nixflix's notification units, which delete this entry.
    partOf = notifications;
    wantedBy = [ "multi-user.target" ] ++ notifications;

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
        local service=$1 port=$2 version=$3 map=$4 key base existing payload method url
        key=$(<"$CREDENTIALS_DIRECTORY/$service-api-key")
        base="http://127.0.0.1:$port/api/$version"
        api() { ${curl} -sSf --max-time 30 -H "X-Api-Key: $key" -H "Content-Type: application/json" "$@"; }

        existing=$(api "$base/notification" | ${jq} -c --arg name ${lib.escapeShellArg name} \
          'map(select(.name == $name))[0] // empty')
        payload=$(api "$base/notification/schema" | ${jq} -c \
          --arg name ${lib.escapeShellArg name} \
          --rawfile token "$CREDENTIALS_DIRECTORY/plex-token" \
          --argjson fields "$(${jq} -c --argjson map "$map" '. + $map' <<<${lib.escapeShellArg (builtins.toJSON fields)})" \
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
        lib.mapAttrsToList (
          service: s:
          "connect ${service} ${toString s.port} ${s.api} ${
            lib.escapeShellArg (builtins.toJSON { inherit (s) mapFrom mapTo; })
          }"
        ) services
      )}
    '';
  };
}
