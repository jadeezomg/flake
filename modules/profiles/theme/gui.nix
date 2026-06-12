# Theme GUI payload (HM half) — pushed only when theme.gui is enabled; the
# headless server keeps the ./home.nix baseline without any of this.
{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}: let
  inherit
    (config.lib.dotfiles)
    mkLiveSymlink
    ;

  # Wallpaper/image data lives in ./wallpapers and ./images; the live
  # symlinks below expose them under ~/Pictures.
  assetsDir = "${config.dotfiles.flakeRoot}/modules/profiles/theme";
in {
  stylix = {
    opacity = {
      applications = 0.7;
      desktop = 0.8;
      popups = 0.8;
      terminal = 0.8;
    };

    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-dark";
      size = 24;
    };

    image = ./wallpapers/wallpaper.jpg;

    targets = {
      gtk.enable = true;
      zen-browser = {
        profileNames = ["default"];
        # opacity.applications = 0.5;
      };
    };
  };

  home.file = {
    "Pictures/Images" = mkLiveSymlink "${assetsDir}/images";
    "Pictures/Wallpapers" = mkLiveSymlink "${assetsDir}/wallpapers";
  };
  gtk = lib.mkIf (!isDarwin) {
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };
}
