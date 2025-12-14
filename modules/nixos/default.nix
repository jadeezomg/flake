{ config, pkgs, ... }:

{
  imports = [
    ./compat.nix
    ./maintenance
  ];
}
