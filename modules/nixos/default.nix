{...}: {
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
    ./gaming
    ./security
    ./services
    ./shells
    ./utils
    ./virtualization
    ./user.nix
    ../../home/nixos/guest/extra-users.nix
  ];
}
