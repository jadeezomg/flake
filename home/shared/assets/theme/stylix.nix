{pkgs, ...}: let
  # Import our custom theme colors
  themeColors = import ./theme.nix;
in {
  stylix = {
    enable = true;
    autoEnable = true;

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

    # Enable automatic theming for all supported applications
    targets = {
      # # Terminals
      # foot.enable = true;
      # ghostty.enable = true;
      # kitty.enable = true;
      # wezterm.enable = true;

      # You already manage `~/.config/wezterm/wezterm.lua` via `home/shared/apps/terminals/wezterm.nix`,
      # so Stylix must NOT also manage WezTerm or we'll get a Home Manager target-file conflict.
      wezterm.enable = false;

      # # Editors
      # helix.enable = true;
      # zed.enable = true;

      # # Browsers
      # firefox.enable = true;
      # zen-browser.enable = true;
      # zen-browser.profileNames = ["default"];

      # # Desktop Environments
      # gnome.enable = true;

      # # Media Players

      # # Other Applications
      # bat.enable = true;
      # btop.enable = true;
      # dunst.enable = true;
      # fzf.enable = true;
      # gtk.enable = true;
      # yazi.enable = true;
      # # rofi.enable = true;
      # # waybar.enable = true;
      # zathura.enable = true;
    };

    # Alternative: Create a custom base16 scheme from theme.nix
    # Uncomment the following and comment out the above if you want exact color matching:
    # base16Scheme = pkgs.writeText "birds-of-paradise-custom.yaml" ''
    #   scheme: "Birds of Paradise (Custom)"
    #   author: "Jeroen de Vries (customized)"
    #   base00: "${themeColors.bg-primary}"  # Default Background
    #   base01: "${themeColors.bg-secondary}"  # Lighter Background
    #   base02: "${themeColors.bg-tertiary}"  # Selection Background
    #   base03: "${themeColors.sidebar-border}"  # Comments, Invisibles
    #   base04: "${themeColors.text-tertiary}"  # Dark Foreground
    #   base05: "${themeColors.text-primary}"  # Default Foreground
    #   base06: "${themeColors.text-secondary}"  # Light Foreground
    #   base07: "${themeColors.text-secondary}"  # Lightest Foreground
    #   base08: "${themeColors.ansi-red}"  # Variables, XML Tags, Markup Link Text
    #   base09: "${themeColors.ansi-yellow}"  # Integers, Boolean, Constants, XML Attributes
    #   base0A: "${themeColors.accent-yellow}"  # Classes, Markup Bold, Search Text Background
    #   base0B: "${themeColors.ansi-green}"  # Strings, Inherited Class, Markup Code
    #   base0C: "${themeColors.ansi-cyan}"  # Support, Regular Expressions, Escape Characters
    #   base0D: "${themeColors.ansi-blue}"  # Functions, Methods, Attribute IDs
    #   base0E: "${themeColors.ansi-magenta}"  # Keywords, Storage, Selector, Markup Italic
    #   base0F: "${themeColors.accent-red}"  # Deprecated, Opening/Closing Embedded Language Tags
    # '';

    # Fonts configuration - matching your existing terminal setup
    fonts = {
      monospace = {
        package = pkgs.nerdfonts.override {
          fonts = ["Iosevka"];
        };
        name = "Iosevka Nerd Font";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
    };

    # Cursor theme (optional, can be customized)
    cursor = {
      package = pkgs.everforest-cursors;
      name = "everforest-cursors";
      size = 24;
    };

    # Image/wallpaper (optional - can be set per host or left unset)
    # image = ./path/to/wallpaper.jpg;
  };
}
