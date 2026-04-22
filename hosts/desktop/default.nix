{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
    ./gpu.nix
    ./display.nix
  ];

  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    gaming.enable = true;
  };

  # System state version — host specific, do not change.
  system.stateVersion = "25.11";
}
