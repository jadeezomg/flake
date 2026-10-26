let
  # The library folders in the media folder of the data share. Plex and
  # Jellyfin see each one as /media/<folder> (../storage.nix).
  mediaFolders = [
    "Series"
    "Anime"
    "Series-PtBr"
    "Cinema"
    "Documentaries Feature"
    "Documentaries"
    "Comedy"
    "Movies"
  ];
in
{
  inherit mediaFolders;

  mountDeps = [
    "data.mount"
    "Music.mount"
    "mnt-library.mount"
  ];

  remoteDirs = map (folder: "/data/media/${folder}") mediaFolders ++ [
    # Recycle bins of Radarr/Sonarr and of Lidarr (arr.nix).
    "/data/media/.recycle"
    "/Music/.recycle"
    "/data/torrents"
    "/data/torrents/sonarr"
    "/data/torrents/radarr"
    "/data/torrents/lidarr"
    "/data/torrents/prowlarr"
    "/data/torrents/default"
    "/data/usenet"
    "/data/usenet/incomplete"
    "/data/usenet/complete"
    "/data/usenet/complete/sonarr"
    "/data/usenet/complete/radarr"
    "/data/usenet/complete/lidarr"
    "/data/usenet/complete/prowlarr"
    "/data/usenet/watch"
    "/data/usenet/nzb-backup"
  ];

  mkLibrary = collectionType: paths: {
    inherit collectionType paths;
    enableRealtimeMonitor = false;
    # Jellyfin's nightly Audio Normalization task scans every album/track for LUFS
    # metadata; on mini it fails 100% (log spam) while ffmpeg works manually.
    enableLUFSScan = false;
    enableTrickplayImageExtraction = false;
    extractTrickplayImagesDuringLibraryScan = false;
    saveLocalMetadata = false;
    saveSubtitlesWithMedia = false;
    saveLyricsWithMedia = false;
    saveTrickplayWithMedia = false;
  };
}
