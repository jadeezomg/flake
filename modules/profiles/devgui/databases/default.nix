# GUI counterpart of devenv.databases (rainfrog TUI stays headless-side).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  packages = pkgs: [ pkgs.tabularis ];
} args
