{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}: {
  boot = {
    loader = {
      systemd-boot = {
        enable = lib.mkForce false;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
