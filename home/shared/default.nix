{...}: {
  imports = [
    ./dotfiles.nix
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
