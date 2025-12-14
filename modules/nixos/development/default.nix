{ config, pkgs, ... }:

{
  imports = [
    ./ides.nix
    ./tools.nix
  ];
}
