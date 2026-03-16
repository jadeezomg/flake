{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./environment
    ./integration
    ./security
    ./user.nix
  ];
}
