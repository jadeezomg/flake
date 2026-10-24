# Theme GUI payload (HM half) — pushed only when theme.gui is enabled; the
# headless server keeps the ./stylix.nix baseline without any of this.
{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    ;

  # Wallpaper/image data lives in ./wallpapers and ./images; the live
  # symlinks below expose them under ~/Pictures.
  assetsDir = "${config.dotfiles.flakeRoot}/modules/profiles/theme";
in
{
  stylix = {
    # Apps draw their content at 90% alpha themselves. Umbriel window rule
    # opacity would also fade the window border, which stays fully opaque.
    # 90% and not 80%: the HDR ultrawide mixes in linear light, so the same
    # alpha looks more transparent there than on the SDR portrait screen.
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
      gtk = {
        enable = true;
        # GTK apps draw their own translucent background, so the compositor
        # border stays opaque. Only the window background carries the
        # opacity. Views are transparent on top of it, and header bars,
        # sidebars, and cards add a light base01 tint: opaque base01 layers
        # would hide the transparency, like the stacked layers in Zen.
        # Popovers are their own surface. In-window dialogs stay opaque.
        extraCss =
          let
            p = config.dotfiles.theme.palette;
            alpha = toString config.stylix.opacity.applications;
          in
          ''
            @define-color window_bg_color alpha(${p.bg-primary}, ${alpha});
            @define-color view_bg_color transparent;
            @define-color headerbar_bg_color alpha(${p.bg-secondary}, 0.4);
            @define-color sidebar_bg_color alpha(${p.bg-secondary}, 0.4);
            @define-color card_bg_color alpha(${p.bg-secondary}, 0.4);
            @define-color popover_bg_color alpha(${p.bg-secondary}, ${alpha});
          '';
      };
      zen-browser = {
        profileNames = [ "default" ];
        # opacity.applications = 0.5;
      };
    };
  };

  home.pointerCursor.enable = lib.mkIf (!isDarwin) true;

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
