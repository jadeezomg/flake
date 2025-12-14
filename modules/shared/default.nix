{ config, pkgs, ... }:

{
  imports = [
    ./apps
    ./boot
    ./desktop
    ./development
    ./environment
    ./fonts
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
