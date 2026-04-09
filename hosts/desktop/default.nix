{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
    ./gpu.nix
    ./display.nix
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "25.11";
}
