{...}: {
  imports = [
    ./profiles
    ./boot.nix
    ./gc.nix
    ./guest-users.nix
    ./hardware.nix
    ./networking.nix
    ./security.nix
    ./usrbinenv.nix
    ./user.nix
    ./virtualization.nix
  ];
}
