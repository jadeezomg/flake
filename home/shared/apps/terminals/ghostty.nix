{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  # Shared ghostty settings - platform-specific files import this and set the package
  programs.ghostty = {
    enable = true;
    settings = {
      # Shell configuration
      shell = "${pkgs.nushell}/bin/nu";

      # General
      resize-overlay = "never";
      link-url = true;
      scrollback-limit = 10000;

      # Typography
      font-family = "Iosevka Nerd Font";
      font-size = 12;

      # Cursor
      cursor-style = "block";
      cursor-style-blink = false; # Enforce no blinking (shell vi mode can interfere)
      shell-integration-features = "no-cursor";
      adjust-cursor-thickness = "2"; # Make cursor line thicker

      # Clipboard
      clipboard-read = "allow";
      clipboard-write = "allow";

      # UI
      window-padding-x = 20;
      window-padding-y = 10;
      window-padding-balance = true;
      background-opacity = 1.0; # This is controlled by the compositor instead
      background-blur = 0;
      mouse-hide-while-typing = true;

      # Colors - Birds of Paradise theme
      foreground = "${themeColors.text-primary}";
      background = "${themeColors.bg-primary}";
      selection-foreground = "${themeColors.text-primary}";
      selection-background = "${themeColors.bg-tertiary}";
      cursor = "${themeColors.text-primary}";
      cursor-text = "${themeColors.bg-primary}";

      # ANSI colors
      color0 = "${themeColors.ansi-black}";
      color1 = "${themeColors.ansi-red}";
      color2 = "${themeColors.ansi-green}";
      color3 = "${themeColors.ansi-yellow}";
      color4 = "${themeColors.ansi-blue}";
      color5 = "${themeColors.ansi-magenta}";
      color6 = "${themeColors.ansi-cyan}";
      color7 = "${themeColors.ansi-white}";

      # Bright ANSI colors
      color8 = "${themeColors.ansi-bright-black}";
      color9 = "${themeColors.ansi-bright-red}";
      color10 = "${themeColors.ansi-bright-green}";
      color11 = "${themeColors.ansi-bright-yellow}";
      color12 = "${themeColors.ansi-bright-blue}";
      color13 = "${themeColors.ansi-bright-magenta}";
      color14 = "${themeColors.ansi-bright-cyan}";
      color15 = "${themeColors.ansi-bright-white}";
    };
  };
}
