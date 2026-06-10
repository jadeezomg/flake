{...}: {
  imports = [
    ./core
    ./env
    ./theme
    ./sops-session-env.nix
    ./sops-keyring.nix
  ];
}
