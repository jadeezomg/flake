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
    ./environment
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
  ];
}
