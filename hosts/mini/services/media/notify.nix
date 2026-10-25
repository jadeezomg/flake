# Media notifications through mini's ntfy (../ntfy.nix).
#
# Radarr/Sonarr/Lidarr publish to the `media` topic: imports, health issues,
# and imports that need a manual action. Grabs and upgrades stay quiet.
# Failed media oneshots post to the `system` topic through ntfy-alert@.
{ config, lib, ... }:
let
  # Oneshots whose failure otherwise only shows in the journal.
  watched = [
    "recyclarr"
    "recyclarr-cleanup-profiles"
    "plex-connect"
    "prowlarr-indexers"
    "radarr-config"
    "sonarr-config"
    "lidarr-config"
    "prowlarr-config"
    "fscache-storage"
  ];
in
{
  nixflix.notif.ntfy = {
    enable = true;
    serverUrl = "http://127.0.0.1:2586";
    topics = [ "media" ];
    accessToken._secret = config.sops.secrets."mini/ntfy/mini-token".path;
    triggers = {
      radarr = [
        "onDownload"
        "onHealthIssue"
        "onManualInteractionRequired"
      ];
      sonarr = [
        "onDownload"
        "onHealthIssue"
        "onManualInteractionRequired"
      ];
      lidarr = [
        "onReleaseImport"
        "onHealthIssue"
        "onDownloadFailure"
        "onImportFailure"
      ];
    };
  };

  # Jellyfin connection. Radarr and Sonarr report /data/media/...; Jellyfin's
  # libraries live under /media, so they map the prefix. Without it, Jellyfin
  # cannot place an import and waits for the 06:30 scan. Lidarr's connection
  # has no mapping fields; Jellyfin's music library uses /Music instead, the
  # same path as Lidarr (nixflix/jellyfin.nix).
  nixflix.notif.jellyfin = {
    services = [
      "radarr"
      "sonarr"
      "lidarr"
    ];
    mapFrom = "/data/media/";
    mapTo = "/media/";
  };

  systemd.services = lib.genAttrs watched (_: {
    onFailure = [ "ntfy-alert@%n.service" ];
  });
}
