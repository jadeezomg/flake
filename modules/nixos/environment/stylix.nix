{pkgs, ...}: let
  # Import the same theme colors used in Home Manager
  themeColors = import ../../../../home/shared/assets/theme/theme.nix;

  # Import font definitions to reuse Iosevka variants
  fontDefinitions = import ../../../../home/shared/assets/fonts/fonts.nix {inherit pkgs;};
  iosevkaAile = fontDefinitions.monospace-pro.iosevka-aile.package;
  iosevkaEtoile = fontDefinitions.monospace-pro.iosevka-etoile.package;
in {
  # Stylix NixOS module - handles system-wide theming including GDM
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
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

    # Use the same wallpaper as Home Manager configuration
    # This will be applied to GDM login screen
    image = ../../../../home/shared/assets/theme/wallpaper.jpg;

    # Fonts configuration - matching Home Manager setup
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
  };
}
