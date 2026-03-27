{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./environment
    ./integration
    ./networking
    ./security
    ./user.nix
  ];
}
