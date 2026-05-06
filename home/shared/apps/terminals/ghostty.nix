{
  pkgs,
  lib,
  config,
  osConfig,
  isDarwin,
  ...
}: {
  # Unified ghostty HM config (P9e).
  # Previously the package/systemd bits lived in platform overlays:
  #   home/nixos/apps/terminals.nix  → pkgs.ghostty + systemd.enable
  #   home/darwin/apps/terminals.nix → pkgs.ghostty-bin
  # Both overlays were single-line package swaps, so they're folded in here
  # via `isDarwin` — the only thing left in home/{nixos,darwin}/apps/ for
  # ghostty would have been import-forwarding.
  programs.ghostty = lib.mkIf (osConfig.dotfiles.profiles.apps.terminals.enable or false) {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # Upstream Linux builds ghostty from source; macOS gets the prebuilt cask.
    package =
      if isDarwin
      then pkgs.ghostty-bin
      else pkgs.ghostty;

    # systemd integration only applies on Linux.
    systemd.enable = !isDarwin;

    settings = {
      # Shell configuration.
      # Ghostty config uses `command` (not `shell`). See:
      # https://ghostty.org/docs/config/reference#command
      # Quote the entire value so Ghostty treats it as a single command line
      # (whitespace-safe).
      # command = "\"${pkgs.fish}/bin/fish -l\"";
      command = "${pkgs.nushell}/bin/nu";

      # General
      resize-overlay = "never";
      link-url = true;
      scrollback-limit = 10000;

      # Typography — driven by stylix
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
      background-opacity = 0.8;
      background-blur = true;
      mouse-hide-while-typing = true;

      # Keybindings. Format: keybind = [ "scope:modifier+key=action" ]
      keybind = [
        # Toggle quick terminal with Super+` (grave accent)
        "global:super+grave_accent=toggle_quick_terminal"
        "ctrl+t=toggle_command_palette"
      ];
    };
  };
}
