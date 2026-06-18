# Cinny — lightweight browser Matrix client for the continuwuity homeserver,
# served at https://cinny.jadee.fyi by the shared Caddy tailnet-node proxy
# (services/caddy.nix).
#
# Static site; config.json is overridden so the only homeserver is matrix.jadee.fyi
# and the custom-server picker is off (personal tailnet-only server). Add a
# Cloudflare A record cinny.jadee.fyi → the mini-proxy node IP, proxy OFF.
{pkgs, ...}: let
  cinny = pkgs.cinny.override {
    conf = {
      defaultHomeserver = 0;
      homeserverList = ["matrix.jadee.fyi"];
      allowCustomHomeservers = false;
    };
  };
in {
  services.caddy.virtualHosts."cinny.jadee.fyi".extraConfig = ''
    import tsnet
    root * ${cinny}
    file_server
    encode gzip zstd
  '';
}
