{...}: {
  imports = [
    ./environment.nix
    ./security.nix
    ./shells.nix
  ];
  documentation.man.enable = true;
}
