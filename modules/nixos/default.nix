{...}: {
  imports = [
    ./profiles
    ./boot.nix
    ./gc.nix
    ./guest-users.nix
    ./hardware.nix
    ./networking.nix
    ./nix-ld.nix
    ./security.nix
    ./usrbinenv.nix
    ./user.nix
    ./virtualization.nix
  ];
}
