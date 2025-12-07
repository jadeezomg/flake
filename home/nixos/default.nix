{
  inputs,
  pkgs,
  config,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # NixOS-specific Home Manager configurations
  # Shared configurations are in home/shared

  # Add home-manager command to PATH
  home.packages = with pkgs; [
    inputs.home-manager.packages.${system}.home-manager
  ];
}
