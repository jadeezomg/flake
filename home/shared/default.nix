{...}: {
  imports = [
    ./compat.nix
    ./apps
    ./assets/theme/stylix.nix
    ./boot
    ./desktop
    ./development
    ./environment
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
  ];
}
