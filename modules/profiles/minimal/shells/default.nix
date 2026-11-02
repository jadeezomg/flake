{ ... }: {
  # Prompt/shell theming + workstation env exports live in the essentials
  # profile (../../essentials/shell-theme, shell-system-env.nix).
  imports = [
    ./core
    ./env
    ./mini-cli.nix
    ./sops-session-env.nix
    ./sops-keyring.nix
  ];
}
