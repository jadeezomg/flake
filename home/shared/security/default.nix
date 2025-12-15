{...}: {
  imports = [
    ./auth.nix
    ./encryption
    ./keyrings.nix
    ./ssh.nix
    ./sudo.nix
  ];
}
