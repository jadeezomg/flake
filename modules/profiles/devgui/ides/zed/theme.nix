{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Comment color tracks the palette's line-highlight (lib/theme-palette.nix).
  commentColor = config.dotfiles.theme.palette.line-highlight;
  # Edit-prediction ghost text. Stylix uses base03, which is too dark on the background.
  predictiveColor = config.dotfiles.theme.palette.ansi-bright-black;
  # Deleted text in diffs. Stylix uses base08, which this palette maps to the
  # cream text color, so the removed overlay had the color of the text on it.
  # The palette red takes its place, with the alphas of the added colors.
  deletedColor = config.dotfiles.theme.palette.ansi-red;
  # Title bar, status bar, and popups. Stylix uses base01 (bg-secondary). The
  # black variant changes only bg-primary, so these stayed brown. With the
  # black variant, they use bg-primary. The line highlight keeps base01,
  # because it is not visible on bg-primary.
  barColor =
    if config.dotfiles.theme.variant == "black" then
      config.dotfiles.theme.palette.bg-primary
    else
      config.dotfiles.theme.palette.bg-secondary;
in
{
  home.activation.zedThemeSurfaceAlpha = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    theme_file="${"$"}{XDG_CONFIG_HOME:-${"$"}HOME/.config}/zed/themes/stylix.json"
    if [ -e "${"$"}theme_file" ]; then
      # If stylix linked a read-only store file, replace link with a writable copy.
      if [ -L "${"$"}theme_file" ]; then
        cp --remove-destination "$(readlink -f "${"$"}theme_file")" "${"$"}theme_file"
      fi

      # Apply per-surface alpha: main background at e0, all other surfaces lighter.
      tmp_file="$(mktemp)"
      ${lib.getExe pkgs.jq} '
        def with_alpha(a):
          if type != "string" then .
          elif test("^#[0-9A-Fa-f]{6}$") then . + a
          elif test("^#[0-9A-Fa-f]{8}$") then sub("..$"; a)
          else .
          end;

        .themes |= map(
          if (.style | type) == "object" then
            .style |= (
              .background                    |= with_alpha("e0")
              | ."surface.background"        |= with_alpha("50")
              | ."editor.background"         |= with_alpha("00")
              | ."editor.gutter.background"  |= with_alpha("50")
              | ."terminal.background"       |= with_alpha("00")
              | ."panel.background"          |= with_alpha("00")
              | ."title_bar.background"      = "${barColor}c0"
              | ."title_bar.inactive_background" |= with_alpha("b0")
              | ."tab_bar.background"        |= with_alpha("00")
              | ."tab.active_background"     |= with_alpha("d0")
              | ."tab.inactive_background"   |= with_alpha("00")
              | ."status_bar.background"     = "${barColor}c0"
              | ."elevated_surface.background" = "${barColor}ff"
              | ."toolbar.background"        |= with_alpha("d0")
              | ."background.appearance"    = "blurred"
              | .syntax.comment.color        = "${commentColor}"
              | ."predictive"                = "${predictiveColor}"
              | .syntax.predictive.color     = "${predictiveColor}"
              | ."version_control.deleted"   = "${deletedColor}ff"
              | ."version_control.word_deleted" = "${deletedColor}59"
              | .deleted                     = "${deletedColor}ff"
              | ."deleted.background"        = "${deletedColor}1a"
              | ."deleted.border"            = "${deletedColor}80"

            )
          else .
          end
        )
      ' "${"$"}theme_file" > "${"$"}tmp_file"
      mv -f "${"$"}tmp_file" "${"$"}theme_file"
    fi
  '';
}
