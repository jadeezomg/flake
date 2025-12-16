{...}: {
  imports = [
    ./compat.nix
    ./apps
    ./assets/theme/stylix.nix
    ./boot
    ./desktop
    ./development
    ./environment
    ./hardware
    ./integration
    ./modules
    ./locale
    ./maintenance
    ./networking
    ./programs
    ./security/encryption
    ./services
    ./shells
    ./utils
    ./virtualization
  ];
}
