{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.notes;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libreoffice
    ];
  };
}
