# Theme GUI payload (HM half) — pushed only when theme.gui is enabled; the
# headless server keeps the ./home.nix baseline without any of this.
{
  config,
  pkgs,
  ...
}: let
  # Wallpaper/image data lives in ./wallpapers and ./images; the live
  # symlinks below expose them under ~/Pictures.
  flakeRoot = config.dotfiles.flakeRoot;
  assetsDir = "${flakeRoot}/modules/profiles/theme";
in {
  stylix = {
    opacity = {
      applications = 0.9;
      desktop = 0.9;
      popups = 0.9;
      terminal = 0.9;
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
      };
    };
  };

  home.file = {
    "Pictures/Images" = {
      source = config.lib.file.mkOutOfStoreSymlink "${assetsDir}/images";
      force = true;
    };

    "Pictures/Wallpapers" = {
      source = config.lib.file.mkOutOfStoreSymlink "${assetsDir}/wallpapers";
      force = true;
    };
  };
}
