{...}: {
  imports = [
    ./dotfiles.nix
    ./nix-client.nix
    ./compat.nix
    ./agents.nix
    ./network
    ./apps
    ./security.nix
    ./assets
    ./development
    ./shells
    ./utils
  ];
}
