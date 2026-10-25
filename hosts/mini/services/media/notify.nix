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

  # Jellyfin connection. The apps report their own paths (/data/media/...,
  # /Music/...); Jellyfin's libraries live under /media. Without the mapping,
  # Jellyfin cannot place an import and waits for the 06:30 scan. Lidarr
  # needs a different mapping, so it gets its own entry.
  nixflix.notif.jellyfin = {
    services = [
      "radarr"
      "sonarr"
    ];
    mapFrom = "/data/media/";
    mapTo = "/media/";
  };
  nixflix.notif.extraNotifications = [
    {
      enable = true;
      name = "Emby / Jellyfin";
      implementationName = "Emby / Jellyfin";
      services = [ "lidarr" ];
      dependencies = [ "jellyfin-api-key.service" ];
      host = config.nixflix.jellyfin.connectionAddress;
      port = config.nixflix.jellyfin.network.internalHttpPort;
      inherit (config.nixflix.jellyfin) apiKey;
      updateLibrary = true;
      mapFrom = "/Music/";
      mapTo = "/media/Music/";
      triggers.lidarr = [
        "onReleaseImport"
        "onUpgrade"
        "onRename"
        "onAlbumDelete"
        "onArtistDelete"
        "onTrackRetag"
      ];
    }
  ];

  systemd.services = lib.genAttrs watched (_: {
    onFailure = [ "ntfy-alert@%n.service" ];
  });
}
