{
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;

    font = {
      package = lib.mkForce pkgs.nerd-fonts.iosevka;
      name = "Iosevka Nerd Font";
      size = 11;
    };

    keybindings = {
      "ctrl+t" = "new_tab";
    };

    settings = {
      # Shell configuration
      shell = "${pkgs.nushell}/bin/nu";
      shell_integration = "enabled";

      # Font (explicit; not using Stylix)
      font_family = "family='Iosevka Nerd Font' style=Regular";
      bold_font = "family='Iosevka Nerd Font' style=Bold";
      italic_font = "family='Iosevka Nerd Font' style=Italic";
      bold_italic_font = "family='Iosevka Nerd Font' style='Bold Italic'";

      # Window configuration
      initial_window_width = 130;
      initial_window_height = 40;
      window_padding_width = 10;
      window_margin_width = 10;

      # Tab bar configuration
      tab_bar_margin_width = 10;
      tab_bar_margin_height = "5 5";
      tab_bar_edge = "top";
      tab_bar_style = "fade";

      # Scrollback
      scrollback_lines = 10000;

      # Background blur (requires opacity < 1; supported on macOS and KDE)
      background_blur = 30;

      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = 0.25;

      # Cursor trail effect
      cursor_trail = 200;
      # Decay times: fastest (0.1s) and slowest (0.4s) for trail fade
      cursor_trail_decay = "0.1 0.4";
      # Minimum cursor movement (in cells) to trigger the trail
      cursor_trail_start_threshold = 2;

      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;

      # HM-managed config: apply after `home-manager switch` (restart kitty or
      # Ctrl+Shift+F5). Disables kitten __watch_conf__ and its inotify use.
      auto_reload_config = -1;
    };
  };
}
