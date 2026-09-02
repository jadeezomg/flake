# Caddy vhosts for the media stack, all behind the shared tsnet snippet.
{ config, lib, ... }:
let
  inherit (import ../lib.nix { inherit lib; }) mkTsnetProxy;
  proxies = [
    {
      domain = "sonarr.jadee.fyi";
      port = 8989;
    }
    {
      domain = "radarr.jadee.fyi";
      port = 7878;
    }
    {
      domain = "lidarr.jadee.fyi";
      port = 8686;
    }
    {
      domain = "prowlarr.jadee.fyi";
      port = 9696;
    }
    # sabnzbd and qbittorrent run in the VPN network namespace, so the target
    # is the namespace address, not loopback.
    {
      domain = "sabnzbd.jadee.fyi";
      upstream = "${config.nixflix.usenetClients.sabnzbd.connectionAddress}:8080";
    }
    {
      domain = "qbittorrent.jadee.fyi";
      upstream = "${config.nixflix.torrentClients.qbittorrent.connectionAddress}:8282";
    }
    {
      domain = "seerr.jadee.fyi";
      port = 5055;
    }
    {
      domain = "bazarr.jadee.fyi";
      port = 6767;
    }
    {
      domain = "jellyfin.jadee.fyi";
      port = 8096;
    }
    {
      domain = "plex.jadee.fyi";
      port = 32400;
    }
  ];
in
{
  services.caddy.virtualHosts = lib.mergeAttrsList (map mkTsnetProxy proxies);
}
