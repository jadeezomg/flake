{...}: {
  imports = [
    ./dotfiles.nix
    ./compat.nix
    ./apps
    ./security.nix
    ./assets
    ./development
    ./shells
    ./utils
  ];
}
