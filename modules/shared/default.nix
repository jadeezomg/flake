{...}: {
  imports = [
    ./environment.nix
    ./fonts.nix
    ./security.nix
    ./shells.nix
  ];
  documentation.man.enable = true;
}
