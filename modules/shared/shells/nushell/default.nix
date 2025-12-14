{ config, pkgs, ... }:

{
  imports = [
    ./aliases.nix
    ./base.nix
    ./env.nix
    ./theme.nix
  ];
}
