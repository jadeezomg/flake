{
  config,
  inputs,
  pkgs,
  pkgsStable,
  lib,
  ...
}: {
  # CachyOS kernel overlay (x86_64-linux only; same as nix-cachyos-kernel README).
  nixpkgs.overlays =
    lib.mkIf (config.nixpkgs.hostPlatform.system == "x86_64-linux") [
      inputs.nix-cachyos-kernel.overlays.pinned
    ];

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
    # CachyOS latest Zen4 when overlay is present (x86_64-linux); otherwise latest (e.g. aarch64)
    kernelPackages =
      if pkgs ? cachyosKernels
      then pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4
      else pkgs.linuxPackages_latest;
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
