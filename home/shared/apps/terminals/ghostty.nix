{
  pkgs,
  config,
  ...
}: {
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    settings = {
      # Shell configuration
      # Ghostty config uses `command` (not `shell`). See: https://ghostty.org/docs/config/reference#command
      # Quote the entire value so Ghostty treats it as a single command line (whitespace-safe).
      # Docs: https://ghostty.org/docs/config/reference#command
      # command = "\"${pkgs.fish}/bin/fish -l\"";
      command = "${pkgs.nushell}/bin/nu";

      # Match shell integration to the shell we're launching.
      # (Optional, but helps avoid weird behavior when auto-detection disagrees.)
      # shell-integration = "fish";

      # General
      resize-overlay = "never";
      link-url = true;
      scrollback-limit = 10000;

      # Typography - using stylix font configuration
      font-family = config.stylix.fonts.monospace.name;
      font-size = 11;

      # Cursor
      cursor-style = "block";
      cursor-style-blink = true;
      shell-integration-features = "no-cursor";
      adjust-cursor-thickness = "2";

      # Clipboard
      clipboard-read = "allow";
      clipboard-write = "allow";

      # UI
      window-title-font-family = config.stylix.fonts.monospace.name;
      window-height = 40;
      window-width = 130;
      window-padding-x = 20;
      window-padding-y = 10;
      window-padding-balance = true;
      background-opacity = 0.8; # This is controlled by the compositor instead
      background-blur = 20;
      mouse-hide-while-typing = true;

      # Colors are automatically applied by stylix based on base24/base16 scheme
      # No manual color configuration needed - stylix handles:
      # - foreground, background
      # - selection colors
      # - cursor colors
      # - All ANSI colors (color0-color15)
    };
  };
}
