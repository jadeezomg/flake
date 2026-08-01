{
  dotfilesLib,
  lib,
  ...
}:
let
  inherit (dotfilesLib.lanHosts) unraid;
  # NFS export prefix, e.g. "192.168.178.62:/mnt/user". The address lives in
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
    "x-systemd.idle-timeout=600"
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

  fileSystems = {
    "/data" = {
      device = share "data";
      fsType = "nfs";
      options = mountOptions;
    };
    "/data/media/Music" = {
      device = share "Music";
      fsType = "nfs";
      options = mountOptions;
      depends = [ "/data" ];
    };
    # /Music and /media are DIRECT NFS mounts, not binds of the /data tree. A bind of
    # a subdirectory of an automounted NFS mount pins the superblock it was created
    # from: when /data expires (idle-timeout above) or is re-mounted during activation,
    # the bind keeps the dead handle and every access returns ESTALE. That wedged plex
    # on 2026-07-31 — `ls /media` → "Stale file handle", so systemd could not set up its
    # ReadOnlyPaths=/media namespace and ExecStartPre failed with 226/NAMESPACE.
    # Mounting the export path directly lets systemd remount each one independently.
    "/Music" = {
      device = share "Music";
      fsType = "nfs";
      options = mountOptions;
    };
    "/media" = {
      device = share "data/media";
      fsType = "nfs";
      options = mountOptions ++ [ "ro" ];
    };
  };

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
    "mini/media/prowlarr/indexers/scenenzbs-api-key" = { };
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
    "mini/media/bazarr/opensubtitles-username".restartUnits = [ "bazarr.service" ];
    "mini/media/bazarr/opensubtitles-password".restartUnits = [ "bazarr.service" ];
    "mini/media/jellyfin/api-key" = { };
    "mini/media/jellyfin/users/jadee-password" = { };
    "mini/media/jellyfin/users/angeli265-password" = { };
    "mini/media/vpn/wireguard-conf" = { };
  };
}
