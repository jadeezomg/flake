{
  config,
  pkgs,
  lib,
  host ? { },
  ...
}:
let
  secureBoot = host.secureBoot or true;
  serverProfile = config.dotfiles.profiles.server.enable;
  zen4 = config.dotfiles.hardware.cpu.zen4.enable;
in
{
  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce (!secureBoot);
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    # Server hosts run the cachyos server-tuned kernel; Zen4 workstations
    # (dotfiles.hardware.cpu.zen4) get the zen4-LTO latest. Falls back to
    # mainline for other CPUs / aarch64 / when the cachyos overlay is absent.
    kernelPackages =
      if pkgs ? cachyosKernels then
        (
          if serverProfile then
            pkgs.cachyosKernels.linuxPackages-cachyos-server
          else if zen4 then
            pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4
          else
            pkgs.linuxPackages_latest
        )
      else
        pkgs.linuxPackages_latest;

    lanzaboote = {
      enable = secureBoot;
      pkiBundle = "/var/lib/sbctl";
    };

    # Plymouth is graphical-only; pointless on a headless host.
    plymouth = lib.mkIf (!serverProfile) {
      enable = true;
      theme = lib.mkForce "blahaj";
      themePackages = [ pkgs.plymouth-blahaj-theme ];
    };
  };
}
