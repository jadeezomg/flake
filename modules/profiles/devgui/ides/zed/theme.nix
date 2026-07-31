{
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  # Comment color tracks the palette's line-highlight (lib/theme-palette.nix).
  commentColor = dotfilesLib.palette.line-highlight;
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
              | ."title_bar.background"      |= with_alpha("c0")
              | ."title_bar.inactive_background" |= with_alpha("b0")
              | ."tab_bar.background"        |= with_alpha("00")
              | ."tab.active_background"     |= with_alpha("d0")
              | ."tab.inactive_background"   |= with_alpha("00")
              | ."status_bar.background"     |= with_alpha("c0")
              | ."toolbar.background"        |= with_alpha("d0")
              | ."background.appearance"    = "blurred"
              | .syntax.comment.color        = "${commentColor}"

            )
          else .
          end
        )
      ' "${"$"}theme_file" > "${"$"}tmp_file"
      mv -f "${"$"}tmp_file" "${"$"}theme_file"
    fi
  '';
}
