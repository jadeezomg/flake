{pkgs, ...}: let
  # Import our custom theme colors
  themeColors = import ./theme.nix;

  # Import font definitions to reuse Iosevka variants
  fontDefinitions = import ../fonts/fonts.nix {inherit pkgs;};
  iosevkaAile = fontDefinitions.monospace-pro.iosevka-aile.package;
  iosevkaEtoile = fontDefinitions.monospace-pro.iosevka-etoile.package;
in {
  stylix = {
    enable = true;
    autoEnable = true;
    overlays.enable = false;

    # Custom base16 scheme created from theme.nix colors
    base16Scheme = {
      scheme = "Birds of Paradise (Base16)";
      author = "Jeroen de Vries (converted to base16)";
      base00 = themeColors.bg-primary;
      base01 = themeColors.bg-secondary;
      base02 = themeColors.bg-tertiary;
      base03 = themeColors.sidebar-border;
      base04 = themeColors.text-tertiary;
      base05 = themeColors.text-primary;
      base06 = themeColors.text-secondary;
      base07 = themeColors.text-secondary;
      base08 = themeColors.ansi-red;
      base09 = themeColors.ansi-yellow;
      base0A = themeColors.accent-yellow;
      base0B = themeColors.ansi-green;
      base0C = themeColors.ansi-cyan;
      base0D = themeColors.ansi-blue;
      base0E = themeColors.ansi-magenta;
      base0F = themeColors.accent-red;
    };

    # Fonts configuration - matching your existing terminal setup
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka;
        name = "Iosevka Nerd Font";
      };
      serif = {
        package = iosevkaEtoile;
        name = "Iosevka Etoile";
      };
      sansSerif = {
        package = iosevkaAile;
        name = "Iosevka Aile";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    # Cursor theme
    cursor = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-dark";
      size = 24;
    };

    # Image/wallpaper
    image = ../wallpapers/wallpaper.jpg;

    # Enable automatic theming for all supported applications
    targets = {
      wezterm.enable = false;
      vscode.enable = false;
      firefox.enable = false;
      "zen-browser" = {
        profileNames = ["default"];
      };
      # gnome.enable = false;
      # qt.enable = false;
      gtk = {
        extraCss = ''
          /* Reduce overall text size across GTK applications */
          * {
            font-size: 10pt;
          }

          /* Reduce GTK decoration font size */
          headerbar.titlebar,
          .titlebar,
          headerbar {
            font-size: 10pt;
          }

          headerbar.titlebar .title,
          .titlebar .title,
          headerbar .title {
            font-size: 10pt;
          }

          /* Specific element text size adjustments */
          label {
            font-size: 10pt;
          }

          button {
            font-size: 10pt;
          }

          entry {
            font-size: 10pt;
          }

          textview text {
            font-size: 10pt;
          }

          menu {
            font-size: 10pt;
          }

          menuitem {
            font-size: 10pt;
          }

          toolbar {
            font-size: 10pt;
          }

          notebook tab {
            font-size: 10pt;
          }

          treeview {
            font-size: 10pt;
          }

          list {
            font-size: 10pt;
          }
        '';
      };
    };
  };
}
