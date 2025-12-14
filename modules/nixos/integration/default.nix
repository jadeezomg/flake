{ config, pkgs, ... }:

{
  imports = [
    ./appimage.nix
    ./binaries.nix
    ./flatpak.nix
  ];
}
