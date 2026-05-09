{...}: {
  imports = [
    ./core
    ./env
    ./theme
    ./sops-session-env.nix
    ./sops-keyring.nix
    ./sops-1password.nix
  ];
}
