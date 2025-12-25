{
  pkgs,
  config,
  ...
}: {
  programs.kitty = {
    enable = true;
    settings = {
      # Shell configuration
      shell = "${pkgs.nushell}/bin/nu";
      shell_integration = "enabled";

      # Font configuration (Stylix owns fonts)
      font_family = config.stylix.fonts.monospace.name;
      font_size = 12;

      # Window configuration
      initial_window_width = 130;
      initial_window_height = 40;
      window_padding_width = 10;
      window_margin_width = 10;

      # Scrollback
      scrollback_lines = 10000;

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
    };
  };
}
