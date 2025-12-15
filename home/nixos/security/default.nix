{...}: {
  imports = [
    ./auth.nix
    ./keyrings.nix
    ./ssh.nix
    ./sudo.nix
    ./password-managers.nix
  ];
}
