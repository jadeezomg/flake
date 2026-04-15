{...}: {
  imports = [
    ./shared
    ./sops-shell-secrets.nix
    ./nushell
    ./fish
    ./bash
    ./zsh
  ];
}
