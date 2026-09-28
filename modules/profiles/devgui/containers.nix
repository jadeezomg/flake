# GUI counterpart of devenv.containers (podman CLI/TUI stay headless-side).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  packages = pkgs: [ pkgs.podman-desktop ];
} args
