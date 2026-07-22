{
  mountDeps = [
    "data.mount"
    "data-media-Music.mount"
    "Music.mount"
    "media.mount"
  ];

  remoteDirs = [
    "/data/media/Series"
    "/data/media/Anime"
    "/data/media/Series-PtBr"
    "/data/media/Cinema"
    "/data/media/Documentaries Feature"
    "/data/media/Documentaries"
    "/data/media/Comedy"
    "/data/media/Movies"
    "/data/media/Music"
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
    "/data/usenet/admin"
    "/data/usenet/logs"
  ];

  mkLibrary = collectionType: paths: {
    inherit collectionType paths;
    enableRealtimeMonitor = false;
    # Jellyfin's nightly Audio Normalization task scans every album/track for LUFS
    # metadata; on mini it fails 100% (log spam) while ffmpeg works manually.
    enableLUFSScan = false;
    saveLocalMetadata = false;
    saveSubtitlesWithMedia = false;
    saveLyricsWithMedia = false;
    saveTrickplayWithMedia = false;
  };
}
