{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  programs.kitty = {
    enable = true;
    settings = {
      # Shell configuration
      shell = "${pkgs.nushell}/bin/nu";
      shell_integration = "enabled";

      # Font configuration
      # Kitty uses fontconfig for fallbacks, but you can specify multiple fonts
      font_family = "Iosevka Nerd Font";
      font_size = 12;

      # Window configuration
      initial_window_width = 130;
      initial_window_height = 40;
      window_padding_width = 0;
      window_margin_width = 0;

      # Scrollback
      scrollback_lines = 10000;

      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = 0.25;

      # Cursor trail effect
      # Enable trail after cursor has been stationary for 200ms
      cursor_trail = 200;
      # Decay times: fastest (0.1s) and slowest (0.4s) for trail fade
      cursor_trail_decay = "0.1 0.4";
      # Minimum cursor movement (in cells) to trigger the trail
      cursor_trail_start_threshold = 2;

      # Colors - Birds of Paradise theme
      foreground = "${themeColors.text-primary}";
      background = "${themeColors.bg-primary}";
      selection_foreground = "${themeColors.text-primary}";
      selection_background = "${themeColors.bg-tertiary}";

      # Cursor colors
      cursor = "${themeColors.text-primary}";
      cursor_text_color = "${themeColors.bg-primary}";

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

      # Tab bar colors
      active_tab_foreground = "${themeColors.text-primary}";
      active_tab_background = "${themeColors.bg-tertiary}";
      inactive_tab_foreground = "${themeColors.text-tertiary}";
      inactive_tab_background = "${themeColors.bg-secondary}";
      tab_bar_background = "${themeColors.bg-secondary}";

      # Titlebar colors
      # For Wayland: set titlebar color to match theme
      # wayland_titlebar_color = "${themeColors.bg-secondary}";
      # For macOS: set titlebar color (if needed)
      macos_titlebar_color = "${themeColors.bg-secondary}";

      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
    };
  };
}
