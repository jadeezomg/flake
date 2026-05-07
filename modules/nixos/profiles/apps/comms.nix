{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.comms;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.protonmail-desktop];
  };
}
