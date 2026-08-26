# GUI counterpart of devenv.databases (rainfrog TUI stays headless-side).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devgui.databases;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tabularis ];
  };
}
