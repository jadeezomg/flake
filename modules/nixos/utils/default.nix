{ config, pkgs, ... }:

{
  imports = [
    ./nix.nix
    ./core.nix
    ./filesystem.nix
    ./monitoring.nix
    ./networking.nix
    ./text.nix
  ];
}
