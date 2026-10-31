# HTTPS for Unraid's web UIs. Unraid serves plain HTTP on the LAN (Use SSL/TLS:
# No). These tailnet-only names put mini's Caddy and its Let's Encrypt
# certificates in front of it. `flake mini dns-sync` creates their DNS records.
{ dotfilesLib, lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;
  inherit (dotfilesLib.lanHosts) unraid;
in
{
  services.caddy.virtualHosts =
    mkTsnetProxy {
      domain = "unraid.jadee.fyi";
      upstream = "${unraid.lan}:80";
    }
    // mkTsnetProxy {
      domain = "jdownloader.jadee.fyi";
      upstream = "${unraid.lan}:7807";
    };
}
