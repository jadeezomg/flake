{
  dotfilesLib,
  lib,
  ...
}:
let
  inherit (dotfilesLib.lanHosts) unraid;
  inherit (import ./nixflix/common.nix) mediaFolders;
  # NFS export prefix, e.g. "192.168.178.200:/mnt/user". The address lives in
  # data/network/lan-hosts.nix because the backup transport and the ssh alias
  # need the same value (Unraid has no hosts/<name>/host.nix — the flake does
  # not build it).
  share = path: "${unraid.lan}:${unraid.shareRoot}/${path}";

  mountOptions = [
    "_netdev"
    "nfsvers=4.2"
    "hard"
    "noatime"
    "nofail"
    "x-systemd.automount"
    "x-systemd.mount-timeout=30s"
  ];
in
{
  users.users.unraid = {
    isSystemUser = true;
    uid = 99;
    group = "users";
    extraGroups = [
      "render"
      "video"
    ];
  };
  users.groups.users.gid = lib.mkForce 100;

  # Every mount here is the root of an Unraid export, and no mount sits below
  # another NFS mount. Unraid gives the folders of a user share synthetic
  # inode numbers, and it gives the media folder a new one every few minutes
  # ("NFS: server ... error: fileid changed" in the kernel log;
  # fuse_remember=-1 did not stop it). A lookup by name recovers from that.
  # A mount does not:
  #   - A mount whose root is such a folder stays "Stale file handle" until it
  #     is mounted again. That was /media, a mount of data/media, on 2026-10-26.
  #   - The kernel detaches each mount below such a folder, so /media/Music and
  #     /data/media/Music disappeared every few minutes.
  # A bind of a folder in /data is no better: it keeps the dead handle when /data
  # is mounted again (Plex failed with 226/NAMESPACE on 2026-07-31).
  fileSystems = {
    "/data" = {
      device = share "data";
      fsType = "nfs";
      options = mountOptions;
    };
    "/Music" = {
      device = share "Music";
      fsType = "nfs";
      options = mountOptions;
    };
    # The data share again, read-only and with FS-Cache (playback-cache.nix),
    # for Plex and Jellyfin. They read it through the links in /media below.
    "/mnt/library" = {
      device = share "data";
      fsType = "nfs";
      options = mountOptions ++ [ "ro" ];
    };
  };

  # /media is a local folder with one link per library folder, and a link to
  # the Music share. The library paths in Plex and Jellyfin, /media/Music
  # included, stay as they were when /media was a mount.
  systemd.tmpfiles.settings."10-media-links" =
    lib.listToAttrs (
      map (
        folder: lib.nameValuePair "/media/${folder}" { "L+".argument = "/mnt/library/media/${folder}"; }
      ) mediaFolders
    )
    // {
      "/media".d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      "/media/Music"."L+".argument = "/Music";
    };

  # NFS read-ahead: the default 256 KiB makes playback a stream of small reads
  # on the Unraid disks. 16 MiB reads ahead in bigger, sequential pieces. NFS
  # mounts get an anonymous backing device ("0:N"), created on each automount.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="bdi", KERNEL=="0:*", ATTR{read_ahead_kb}="16384"
  '';

  sops.secrets = {
    "mini/media/sonarr/api-key" = { };
    "mini/media/sonarr/password" = { };
    "mini/media/radarr/api-key" = { };
    "mini/media/radarr/password" = { };
    "mini/media/lidarr/api-key" = { };
    "mini/media/lidarr/password" = { };
    "mini/media/prowlarr/api-key" = { };
    "mini/media/prowlarr/password" = { };
    "mini/media/prowlarr/indexers/nzbgeek-api-key" = { };
    "mini/media/prowlarr/indexers/treasuremaps-api-key" = { };
    "mini/media/sabnzbd/api-key" = { };
    "mini/media/sabnzbd/nzb-key" = { };
    "mini/media/sabnzbd/username" = { };
    "mini/media/sabnzbd/password" = { };
    "mini/media/sabnzbd/premiumize-username" = { };
    "mini/media/sabnzbd/premiumize-password" = { };
    "mini/media/qbittorrent/password" = {
      # WebUI hash is derived at qbittorrent start; Arr clients re-read on restart.
      restartUnits = [
        "qbittorrent.service"
        "sonarr.service"
        "radarr.service"
        "lidarr.service"
        "prowlarr.service"
      ];
    };
    "mini/media/bazarr/api-key".restartUnits = [ "bazarr.service" ];
    "mini/media/bazarr/opensubtitles-username".restartUnits = [ "bazarr.service" ];
    "mini/media/bazarr/opensubtitles-password".restartUnits = [ "bazarr.service" ];
    "mini/media/jellyfin/api-key" = { };
    "mini/media/jellyfin/users/jadee-password" = { };
    "mini/media/jellyfin/users/angeli265-password" = { };
    "mini/media/vpn/wireguard-conf" = { };
  };
}
