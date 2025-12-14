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
    ./shell
    ./shells
    ./utils
    ./virtualization
  ];
}
