{...}: {
  imports = [
    ./dotfiles.nix
    ./compat.nix
    ./agents.nix
    ./apps
    ./security.nix
    ./assets
    ./development
    ./shells
    ./utils
  ];
}
