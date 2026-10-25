# Nightly backup of the media stack's state to Unraid: Arr databases and
# settings, Jellyfin/Plex libraries and watch state, Seerr requests,
# SABnzbd/qBittorrent settings. Artwork, metadata caches, logs, and the
# transcode dir are left out; the apps download or recreate them.
#
# Same transport as the Immich backup (../immich-backup.nix): restic over SFTP
# with the `unraid-backup` ssh alias, into its own repo on the `backup` share.
# The apps also write their own consistent backups (Arr: */Backups, Plex:
# dated database copies), which this snapshot includes.
{
  config,
  dotfilesLib,
  host,
  ...
}:
let
  inherit (dotfilesLib.lanHosts) unraid;
  plex = "/srv/nixflix/plex/Plex Media Server";
in
{
  assertions = [
    {
      # The ssh alias and the restic password live in immich-backup.nix.
      assertion = host.miniImmich or false;
      message = "media/backup.nix needs the unraid-backup ssh alias from services/immich-backup.nix (host.miniImmich).";
    }
  ];

  services.restic.backups.media = {
    repository = "sftp:unraid-backup:${unraid.shareRoot}/backup/media";
    passwordFile = config.sops.secrets."mini/backup/restic-password".path;
    initialize = true;
    paths = [
      "/srv/nixflix"
      "/var/lib/private/seerr"
      "/var/lib/sabnzbd"
      "/var/lib/qBittorrent"
    ];
    exclude = [
      "/srv/nixflix/*/MediaCover"
      "/srv/nixflix/*/logs"
      "/srv/nixflix/*/logs.db*"
      "/srv/nixflix/jellyfin/metadata"
      "/srv/nixflix/jellyfin/log"
      "/srv/nixflix/jellyfin-cache"
      "/srv/nixflix/plex-transcode"
      "${plex}/Cache"
      "${plex}/Codecs"
      "${plex}/Crash Reports"
      "${plex}/Diagnostics"
      "${plex}/Logs"
      "${plex}/Media"
      "${plex}/Metadata"
      "${plex}/Updates"
      "/var/lib/sabnzbd/logs"
    ];
    extraBackupArgs = [
      "--tag media"
      "--exclude-caches"
    ];
    # The repo is a few GB, so retention and a partial check run nightly.
    pruneOpts = [
      "--tag media"
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
    runCheck = true;
    checkOpts = [ "--read-data-subset=5%" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:15:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };

  systemd.services.restic-backups-media.onFailure = [
    "ntfy-alert@%n.service"
    "backup-notify@%n.service"
  ];
}
