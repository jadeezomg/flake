{...}: {
  imports = [
    ./boot.nix
    ./gc.nix
    ./guest-users.nix
    ./hardware.nix
    ./networking.nix
    ./nix-ld.nix
    ./openssh.nix
    ./security.nix
    ./sops.nix
    ./usrbinenv.nix
    ./user.nix
    ./virtualization.nix
  ];
}
