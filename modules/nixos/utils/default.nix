{
  config,
  pkgs,
  ...
}: {
  imports = [
    #./nix-ld.nix
    ./core.nix
    ./filesystem.nix
    ./monitoring.nix
    ./networking.nix
    ./text.nix
  ];
}
