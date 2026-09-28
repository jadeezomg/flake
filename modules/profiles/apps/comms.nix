{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "apps" ];
  # Linux-only; darwin comms (slack, …) come via the work profile's homebrew.
  linuxPackages = pkgs: [ pkgs.protonmail-desktop ];
} args
