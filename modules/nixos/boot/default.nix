{
  pkgs,
  pkgsStable,
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
        efiSysMountPoint = "/boot";
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    plymouth = {
      enable = true;
      theme = lib.mkForce "blahaj";
      themePackages = [pkgs.plymouth-blahaj-theme];
    };
  };
}
