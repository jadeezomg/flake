{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.media;
in
{
  config = lib.mkIf cfg.enable {
    # HM half: desktop entry for pear-desktop (no upstream .desktop file).
    home-manager.sharedModules = [
      {
        xdg.desktopEntries."pear-desktop" = {
          name = "Pear Desktop";
          genericName = "YouTube Music Desktop";
          exec = "pear-desktop";
          icon = "pear-desktop";
          terminal = false;
          categories = [
            "Audio"
            "Music"
            "Player"
          ];
          comment = "YouTube Music Desktop Client";
        };
      }
    ];

    environment.systemPackages = with pkgs; [
      pear-desktop # YouTube Music desktop client
      gradia # Screenshot annotation
      pinta # Lightweight raster editor
    ];

    programs.obs-studio.enable = true;
  };
}
