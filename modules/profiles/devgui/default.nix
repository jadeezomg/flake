# devgui — GUI dev tooling, mirroring devenv's category names so a tool
# area's GUI counterpart is always in the predictable place. Default off;
# workstations enable it; server-class hosts are asserted off.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devgui;
in
{
  imports = [
    ./containers.nix
    ./ides
  ];

  config = lib.mkIf cfg.enable {
    dotfiles.profiles.devgui = {
      containers.enable = lib.mkDefault true;
      ides.enable = lib.mkDefault true;
    };

    # Linux-only GTK4/libadwaita Git client (no darwin package).
    environment.systemPackages = lib.optionals (!isDarwin) [ pkgs.gitte ];
  };
}
