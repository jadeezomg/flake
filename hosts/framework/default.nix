{inputs, ...}: {
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    inputs.framework-control.nixosModules.default
    ../../modules/shared
    ../../modules/nixos
    ./gpu.nix
    ./input.nix
    ./power.nix
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "25.11";
}
