{...}: {
  imports = [
    ./dotfiles.nix
    ./nix-client.nix
    ./compat.nix
    ./agents.nix
    ./network
    ./apps
    ./security.nix
    ./development
    ./shells
    ./utils
  ];
}
