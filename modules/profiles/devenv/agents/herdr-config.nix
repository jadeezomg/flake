# herdr configuration. Home Manager owns ~/.config/herdr/config.toml, so the
# file is read-only: herdr cannot save settings from its UI, and
# `herdr config reset-keys` fails. Change the values here instead.
#
# The prefix list holds one chord for each way to press Caps+A:
#   - hyper+a: Linux, where XKB caps:hyper makes Caps a Hyper key. Only kitty
#     reports Hyper (KITTY_WAYLAND_DETECT_MODIFIERS, desktop/default.nix).
#   - ctrl+alt+shift+super+a: macOS, where Vorssaint makes Caps press all four
#     modifiers (work/darwin/brew-casks/vorssaint.nix).
#   - ctrl+b: herdr's default, for terminals that cannot report Hyper.
# Hyper+Space is Handy on both systems, so the prefix does not use it.
{ pkgs, ... }:
{
  xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-config.toml" {
    onboarding = false;
    theme = {
      name = "terminal";
      auto_switch = false;
    };
    ui = {
      status_indicators = "symbols";
      # The outer terminal shows the notification. This also works over SSH,
      # for example from the herdr server on mini, which has no desktop.
      toast.delivery = "terminal";
      # The herdr server resolves these, so an attach to mini shows mini's values.
      tab_bar_right = [
        { type = "zoom"; }
        { type = "hostname"; }
        {
          type = "datetime";
          format = "%H:%M";
        }
      ];
      tab_bar_right_separator = " · ";
    };
    # Nix installs herdr (llm-agents input), so herdr's own update notice is noise.
    update.version_check = false;
    # Keep pane screen history when the server restarts after a Nix update.
    experimental.pane_history = true;
    keys = {
      prefix = [
        "hyper+a"
        "ctrl+alt+shift+super+a"
        "ctrl+b"
      ];
      # prefix+d (d for diff): an Alt chord can type a character on macOS.
      command = [
        {
          key = "prefix+d";
          type = "pane";
          command = ''cd "''${HERDR_ACTIVE_PANE_CWD:-.}" && exec ${pkgs.llm-agents.tuicr}/bin/tuicr --no-update-check -w'';
          description = "review uncommitted changes (tuicr)";
        }
      ];
    };
  };
}
