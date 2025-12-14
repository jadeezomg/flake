{ config, pkgs, ... }:

{
  imports = [
    ./auth.nix
    ./keyrings.nix
    ./ssh.nix
    ./sudo.nix
  ];
}
