{ config, ... }:
{
  services.caddy.virtualHosts = {
    "sonarr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:8989
    '';
    "radarr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:7878
    '';
    "lidarr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:8686
    '';
    "prowlarr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:9696
    '';
    "sabnzbd.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy ${config.nixflix.usenetClients.sabnzbd.connectionAddress}:8080
    '';
    "qbittorrent.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy ${config.nixflix.torrentClients.qbittorrent.connectionAddress}:8282
    '';
    "seerr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:5055
    '';
    "bazarr.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:6767
    '';
    "jellyfin.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:8096
    '';
    "plex.jadee.fyi".extraConfig = ''
      import tsnet
      reverse_proxy 127.0.0.1:32400
    '';
  };
}
