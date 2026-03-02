{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./apps
    ./environment
    ./integration
    ./security
    ./user.nix
  ];
}
