{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.media;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pear-desktop # YouTube Music desktop client
      gradia # Screenshot annotation
      pinta # Lightweight raster editor
    ];

    programs.obs-studio.enable = true;
  };
}
