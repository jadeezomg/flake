{
  pkgs,
  lib,
  ...
}: let
  pear-desktop = import ../../../../packages/pear-desktop/default.nix {inherit pkgs lib;};
in {
  # Pear Desktop - YouTube Music desktop app
  # https://github.com/pear-devs/pear-desktop
  home.packages = [pear-desktop];
}
