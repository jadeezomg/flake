{...}: {
  # Theme submodules gate on `osConfig.dotfiles.profiles.essentials.enable`.
  imports = [
    ./starship.nix
    ./nushell-env.nix
  ];
}
