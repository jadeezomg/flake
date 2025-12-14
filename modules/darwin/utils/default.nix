{ config, pkgs, ... }:

{
  imports = [
    ./core.nix
    ./filesystem.nix
    ./text.nix
    ./monitoring.nix
    ./networking.nix
    ./nix.nix
  ];
}
