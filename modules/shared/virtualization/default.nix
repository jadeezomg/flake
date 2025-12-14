{ config, pkgs, ... }:

{
  imports = [
    ./vm-variants.nix
    ./docker-amd.nix
    ./docker-nvidia.nix
  ];
}
