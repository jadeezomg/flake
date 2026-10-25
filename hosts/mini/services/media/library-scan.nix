# Library scans in one fixed daily window, not at random intervals.
#
# Radarr/Sonarr imports already reach Plex (plex-connect.nix) and Jellyfin
# (nixflix notif) right away. Plex's own daily scan and Jellyfin's 12 h scan
# only woke the Unraid disks at random times. Libraries that no Arr app
# manages (Comedy, Documentaries, Gaming Videos) still need a scan, so
# media-library-scan refreshes everything at 06:30, after the mover's 06:00
# slot, when the disks are often awake anyway.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  curl = lib.getExe pkgs.curl;
  jq = lib.getExe pkgs.jq;
  plex = "http://127.0.0.1:32400";
  jellyfin = "http://127.0.0.1:8096";

  serviceConfig = name: {
    Type = "oneshot";
    DynamicUser = true;
    RuntimeDirectory = name;
    LoadCredential = [
      "plex-token:${config.sops.secrets."mini/media/plex/token".path}"
      "jellyfin-api-key:${config.sops.secrets."mini/media/jellyfin/api-key".path}"
    ];
  };

  # Header files, so the tokens are not on a command line. `wait_for <url>`
  # gives a service that just started up to 2 minutes.
  prelude = ''
    set -euo pipefail
    umask 077
    printf 'X-Plex-Token: %s\n' "$(<"$CREDENTIALS_DIRECTORY/plex-token")" >"$RUNTIME_DIRECTORY/plex"
    printf 'X-Emby-Token: %s\n' "$(<"$CREDENTIALS_DIRECTORY/jellyfin-api-key")" >"$RUNTIME_DIRECTORY/jellyfin"
    plex() { ${curl} -sSf --max-time 30 -H @"$RUNTIME_DIRECTORY/plex" -H "Accept: application/json" "$@"; }
    jellyfin() { ${curl} -sSf --max-time 30 -H @"$RUNTIME_DIRECTORY/jellyfin" -H "Content-Type: application/json" "$@"; }
    wait_for() {
      for _ in $(seq 60); do "$1" "$2" >/dev/null 2>&1 && return; sleep 2; done
      echo "$2 did not answer" >&2; return 1
    }
  '';
in
{
  systemd.services = {
    # Turns the periodic scans off; reapplied at each boot and deploy.
    media-library-schedule = {
      description = "Turn off the periodic Plex and Jellyfin library scans";
      after = [
        "plex.service"
        "jellyfin.service"
      ];
      wantedBy = [ "multi-user.target" ];
      onFailure = [ "ntfy-alert@%n.service" ];
      serviceConfig = serviceConfig "media-library-schedule";
      script = ''
        ${prelude}
        wait_for plex ${plex}/identity
        plex -X PUT "${plex}/:/prefs?ScheduledLibraryUpdatesEnabled=0" >/dev/null
        echo "plex: periodic library scan off"

        wait_for jellyfin ${jellyfin}/System/Info
        id=$(jellyfin ${jellyfin}/ScheduledTasks | ${jq} -r '.[] | select(.Key == "RefreshLibrary") | .Id')
        jellyfin -X POST --data '[]' "${jellyfin}/ScheduledTasks/$id/Triggers" >/dev/null
        echo "jellyfin: Scan Media Library has no schedule"
      '';
    };

    media-library-scan = {
      description = "Scan all Plex and Jellyfin libraries";
      onFailure = [ "ntfy-alert@%n.service" ];
      serviceConfig = serviceConfig "media-library-scan";
      script = ''
        ${prelude}
        wait_for plex ${plex}/identity
        wait_for jellyfin ${jellyfin}/System/Info
        for key in $(plex ${plex}/library/sections | ${jq} -r '.MediaContainer.Directory[].key'); do
          plex "${plex}/library/sections/$key/refresh" >/dev/null
        done
        echo "plex: refresh started for all sections"
        jellyfin -X POST ${jellyfin}/Library/Refresh >/dev/null
        echo "jellyfin: library scan started"
      '';
    };
  };

  systemd.timers.media-library-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*-*-* 06:30:00";
  };
}
