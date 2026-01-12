{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./apps
    ./boot
    ./desktop
    ./development
    ./fonts
    ./hardware
    ./integration
    ./locale
    ./maintenance
    ./networking
    ./programs
    ./security
    ./services
    ./shells
    ./utils
    ./virtualization
    ./user.nix
  ];
}
