{ config, pkgs, ... }:

{
  imports = [
    ./nix.nix
    ./dconf.nix
    ./mime.nix
  ];
}
