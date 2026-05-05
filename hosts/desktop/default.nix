{
  config,
  inputs,
  pkgs,
  ...
}: let
  # Local zenpower5 build — drops corecycler's broken `cachyos` pname regex that forces
  # clang on GCC-built CachyOS kernels. Same source/rev as corecycler.
  zenpower5 = pkgs.callPackage ./zenpower5.nix {
    inherit (config.boot.kernelPackages) kernel;
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
    ./gpu.nix
    ./display.nix
    ./profiles.nix
    inputs.corecycler.nixosModules.default
  ];

  services.corecycler = {
    enable = true;
    unfreeBackends = true; # include mprime (best for CO tuning)
    deviceAccessUser = "jadee"; # required — user added to the corecycler group
    # Disable corecycler's bundled ryzen_smu and zenpower5 derivations: their build
    # heuristic flags any kernel with "cachyos" in pname as LLVM-built and forces clang,
    # but the xddxdd cachyos flake we use builds with GCC. Re-wired below using nixpkgs'
    # ryzen-smu (same amkillam fork/rev) and a local zenpower5 derivation.
    ryzenSmu = false;
    zenpower = false;
    nct6775 = true;
    spd5118 = true;
  };

  boot.kernelModules = ["ryzen_smu" "zenpower"];
  boot.extraModulePackages = [
    config.boot.kernelPackages.ryzen-smu
    zenpower5
  ];
  # zenpower5 conflicts with k10temp (same PCI device); corecycler does this when its
  # zenpower option is enabled — replicate here since we disabled it.
  boot.blacklistedKernelModules = ["k10temp"];

  # SMU sysfs: mirror corecycler's group access for Curve Optimizer (gated there by ryzenSmu).
  systemd.tmpfiles.rules = [
    "z /sys/kernel/ryzen_smu_drv/smu_args 0660 root corecycler - -"
    "z /sys/kernel/ryzen_smu_drv/mp1_smu_cmd 0660 root corecycler - -"
    "z /sys/kernel/ryzen_smu_drv/rsmu_cmd 0660 root corecycler - -"
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "25.11";
}
