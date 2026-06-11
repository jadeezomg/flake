{inputs, ...}: {
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    inputs.framework-control.nixosModules.default
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./input.nix
    ./power.nix
    ./profiles.nix
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
