{config, ...}: {
  # DMS is now managed via NixOS module (modules/nixos/programs/default.nix)
  # Only manage Niri configuration files here
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
}
