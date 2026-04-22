{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.files;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nautilus # GNOME file manager
    ];
  };
}
