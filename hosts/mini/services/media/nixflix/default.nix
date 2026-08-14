_:
let
  inherit (import ./common.nix) mountDeps;
in
{
  imports = [
    ./arr.nix
    ./downloaders.nix
    ./jellyfin.nix
    ./setup.nix
  ];

  nixflix = {
    enable = true;
    mediaDir = "/data/media";
    downloadsDir = "/data";
    stateDir = "/srv/nixflix";
    serviceDependencies = mountDeps ++ [ "nixflix-setup-remote-dirs.service" ];

    globals.libraryOwner = {
      user = "unraid";
      group = "users";
    };

    postgres.enable = false;
    caddy.enable = false;
    nginx.enable = false;
    seerr.enable = false;
  };
}
