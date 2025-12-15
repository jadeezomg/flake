{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./firefox.nix
    ./zen.nix
  ];
}
