{ lib, ... }:
let
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
      device = "192.168.178.62:/mnt/user/data";
      fsType = "nfs";
      options = mountOptions;
    };
    "/data/media/Music" = {
      device = "192.168.178.62:/mnt/user/Music";
      fsType = "nfs";
      options = mountOptions;
      depends = [ "/data" ];
    };
    "/Music" = {
      device = "/data/media/Music";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/data/media/Music" ];
    };
    "/media" = {
      device = "/data/media";
      fsType = "none";
      options = [
        "bind"
        "ro"
      ];
      depends = [ "/data/media" ];
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
    "mini/media/qbittorrent/password" = { };
    "mini/media/bazarr/opensubtitles-username".restartUnits = [ "bazarr.service" ];
    "mini/media/bazarr/opensubtitles-password".restartUnits = [ "bazarr.service" ];
    "mini/media/jellyfin/api-key" = { };
    "mini/media/jellyfin/users/jadee-password" = { };
    "mini/media/jellyfin/users/angeli265-password" = { };
    "mini/media/vpn/wireguard-conf" = { };
  };
}
