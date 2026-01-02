{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./binaries.nix
    ./homebrew.nix
  ];
}
