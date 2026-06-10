# devgui — GUI dev tooling, mirroring devenv's category names so a tool
# area's GUI counterpart is always in the predictable place. Default off;
# workstations enable it; server-class hosts are asserted off.
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.devgui;
in {
  imports = [
    ./containers.nix
    ./ides.nix
  ];

  config = lib.mkIf cfg.enable {
    dotfiles.profiles.devgui = {
      containers.enable = lib.mkDefault true;
      ides.enable = lib.mkDefault true;
    };
  };
}
