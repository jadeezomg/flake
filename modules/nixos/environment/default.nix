{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./dconf.nix
    ./mime.nix
    ./nix.nix
    ./stylix.nix
  ];
}
