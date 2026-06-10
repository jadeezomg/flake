{...}: {
  # Prompt/shell theming + workstation env exports live in the essentials
  # profile (../../essentials/shell-theme, shell-system-env.nix).
  imports = [
    ./core
    ./env
    ./sops-session-env.nix
    ./sops-keyring.nix
  ];
}
