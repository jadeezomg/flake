{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./podman.nix
    ./vm-variants.nix
  ];
}
