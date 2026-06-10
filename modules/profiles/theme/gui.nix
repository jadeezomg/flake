# Theme GUI payload (HM half) — pushed only when theme.gui is enabled; the
# headless server keeps the ./home.nix baseline without any of this.
{
  config,
  pkgs,
  ...
}: let
  inherit
    (import ../../../lib/home/live-xdg-symlinks.nix {inherit config;})
    mkLiveSymlink
    ;

  # Wallpaper/image data lives in ./wallpapers and ./images; the live
  # symlinks below expose them under ~/Pictures.
  assetsDir = "${config.dotfiles.flakeRoot}/modules/profiles/theme";
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
    "Pictures/Images" = mkLiveSymlink "${assetsDir}/images";
    "Pictures/Wallpapers" = mkLiveSymlink "${assetsDir}/wallpapers";
  };
}
