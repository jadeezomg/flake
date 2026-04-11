{
  lib,
  pkgs,
  ...
}: {
  programs.zed-editor = {
    userSettings = {
      # Let Stylix override theme selection.
    };
  };

  # Workarounds for zed + stylix:
  # - force unsupported `appearance: "unspecified"` to `"dark"` (stylix #2267)
  # - add subtle transparency to major background surfaces.
  home.activation.zedFixStylixAppearance = lib.hm.dag.entryAfter ["linkGeneration"] ''
    theme_file="${"$"}{XDG_CONFIG_HOME:-${"$"}HOME/.config}/zed/themes/stylix.json"
    alpha="d0" # 90% opacity
    if [ -e "${"$"}theme_file" ]; then
      # If stylix linked a read-only store file, replace link with a writable copy.
      if [ -L "${"$"}theme_file" ]; then
        cp --remove-destination "$(readlink -f "${"$"}theme_file")" "${"$"}theme_file"
      fi

      # Replace any unsupported zed value with a valid one.
      sed -i 's/"appearance":[[:space:]]*"unspecified"/"appearance":"dark"/g' "${"$"}theme_file"

      # Apply alpha to selected theme background surfaces.
      tmp_file="$(mktemp)"
      ${lib.getExe pkgs.jq} --arg a "${"$"}alpha" '
        def with_alpha:
          if type != "string" then .
          elif test("^#[0-9A-Fa-f]{6}$") then . + $a
          elif test("^#[0-9A-Fa-f]{8}$") then sub("..$"; $a)
          else .
          end;

        .themes |= map(
          if (.style | type) == "object" then
            .style |= (
              .background |= with_alpha
              | ."surface.background" |= with_alpha
              | ."editor.background" |= with_alpha
              | ."editor.gutter.background" |= with_alpha
              | ."terminal.background" |= with_alpha
              | ."panel.background" |= with_alpha
              | ."title_bar.background" |= with_alpha
              | ."title_bar.inactive_background" |= with_alpha
              | ."tab_bar.background" |= with_alpha
              | ."tab.active_background" |= with_alpha
              | ."tab.inactive_background" |= with_alpha
            )
          else .
          end
        )
      ' "${"$"}theme_file" > "${"$"}tmp_file"
      mv -f "${"$"}tmp_file" "${"$"}theme_file"
    fi
  '';
}
