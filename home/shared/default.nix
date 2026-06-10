{...}: {
  imports = [
    ./dotfiles.nix
    ./nix-client.nix
    ./compat.nix
    ./agents.nix
    ./network
    ./security.nix
    ./shells
    ./utils
  ];
}
