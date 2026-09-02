# devgui — GUI dev tooling, mirroring devenv's category names so a tool
# area's GUI counterpart is always in the predictable place. Default off;
# workstations enable it; server-class hosts are asserted off.
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  imports = [
    ./agents
    ./containers.nix
    ./databases.nix
    ./ides
  ];
  # Linux-only GTK4/libadwaita Git client (no darwin package).
  linuxPackages = pkgs: [ pkgs.gitte ];
} args
