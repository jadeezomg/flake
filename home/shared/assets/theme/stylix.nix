{
  host,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  # Import our custom theme colors
  themeColors = import ./theme.nix;

  # Import font definitions to reuse Iosevka variants
  fontDefinitions = import ../fonts/fonts.nix {inherit pkgs;};
  # iosevkaAile = fontDefinitions.monospace-pro.iosevka-aile.package;
  iosevkaEtoile = fontDefinitions.monospace-pro.iosevka-etoile.package;
in {
  stylix = {
    enable = true;
    autoEnable = true;
    opacity = {
      applications = 0.9;
      desktop = 0.9;
      popups = 0.9;
      terminal = 0.9;
    };
    overlays.enable = false;
    polarity = "dark";

    # Custom base16 scheme created from theme.nix colors
    base16Scheme = {
      scheme = "Birds of Paradise";
      author = "Jeroen de Vries";
      base00 = themeColors.bg-primary;
      base01 = themeColors.bg-secondary;
      base02 = themeColors.bg-tertiary;
      base03 = themeColors.sidebar-border;
      base04 = themeColors.text-tertiary;
      base05 = themeColors.text-primary;
      base06 = themeColors.text-secondary;
      base07 = themeColors.text-secondary;
      base08 = themeColors.text-primary;
      base09 = themeColors.ansi-yellow;
      base0A = themeColors.accent-yellow;
      base0B = themeColors.ansi-green;
      base0C = themeColors.ansi-cyan;
      base0D = themeColors.ansi-blue;
      base0E = themeColors.ansi-magenta;
      base0F = themeColors.accent-red;
    };

    fonts = {
      sizes.applications = 10;
      monospace = {
        package = pkgs.nerd-fonts.iosevka;
        name = "Iosevka Nerd Font";
      };
      serif = {
        package = iosevkaEtoile;
        name = "Iosevka Etoile";
      };
      sansSerif = {
        name = "Inter Variable";
      };
      # sansSerif = {
      #   package = iosevkaAile;
      #   name = "Iosevka Aile";
      # };
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

    targets = {
      vscode.enable = false;
      firefox.enable = false;
      kitty = {
        enable = true;
        fonts.enable = false;
      };
      ghostty.fonts.enable = false;
      zen-browser = {
        profileNames = ["default"];
      };
      # gnome.enable = false;
      # qt.enable = false;
      # GTK/dconf theming requires a user dconf service (graphical session). Skip
      # on headless NixOS (mini); Darwin keeps GTK even without `mainMonitor`.
      gtk.enable = lib.mkDefault (isDarwin || (host ? mainMonitor));
    };
  };
}
