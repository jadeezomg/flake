{ ... }:

{
  imports = [
    ./docker-amd.nix
    ./docker-nvidia.nix
    ./vm-variants.nix
  ];
}
