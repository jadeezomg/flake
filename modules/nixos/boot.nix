{
  config,
  pkgs,
  lib,
  ...
}: let
  serverProfile = config.dotfiles.profiles.server.enable;
in {
  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce false;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    # Server hosts run the cachyos server-tuned kernel (no zen4 LTO desktop tuning);
    # desktop hosts get the zen4 latest. Falls back to mainline on aarch64 / when
    # the cachyos overlay is absent.
    kernelPackages =
      if pkgs ? cachyosKernels
      then
        (
          if serverProfile
          then pkgs.cachyosKernels.linuxPackages-cachyos-server
          else pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4
        )
      else pkgs.linuxPackages_latest;

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # Plymouth is graphical-only; pointless on a headless host.
    plymouth = lib.mkIf (!serverProfile) {
      enable = true;
      theme = lib.mkForce "blahaj";
      themePackages = [pkgs.plymouth-blahaj-theme];
    };
  };
}
