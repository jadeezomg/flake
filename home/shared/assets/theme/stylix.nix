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
    polarity = "dark";

    # Custom base16 scheme created from theme.nix colors
    # This converts the base24 Birds of Paradise theme to base16 format
    # Important: YAML must start at column 0 (no indentation), otherwise base16.nix won't parse it.
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

    # scheme: "Birds of Paradise (Base16)"
    # author: "Jeroen de Vries (converted to base16)"
    # base00: "372725"
    # base01: "2e201f"
    # base02: "5B413D"
    # base03: "6a4d32"
    # base04: "DDDDDD"
    # base05: "E6E1C4"
    # base06: "feffff"
    # base07: "feffff"
    # base08: "cb4131"
    # base09: "eeac36"
    # base0A: "EFCB43"
    # base0B: "6ba18a"
    # base0C: "85b4bb"
    # base0D: "6b98bb"
    # base0E: "bb94b4"
    # base0F: "A40042"

    # Enable automatic theming for all supported applications
    targets = {
      # Terminals
      # You already manage `~/.config/wezterm/wezterm.lua` via `home/shared/apps/terminals/wezterm.nix`,
      # so Stylix must NOT also manage WezTerm or we'll get a Home Manager target-file conflict.
      wezterm.enable = false;

      # Editors
      vscode.enable = false;

      # Browsers
      firefox.enable = false;
      # firefox.profileNames = ["default"];
      zen-browser.profileNames = ["default"];

      # Desktop Environments
      gnome.enable = true;
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

    # Cursor theme (optional, can be customized)
    cursor = {
      package = pkgs.everforest-cursors;
      name = "everforest-cursors";
      size = 24;
    };

    # Image/wallpaper (optional - can be set per host or left unset)
    image = ./wallpaper.jpg;
  };
}
