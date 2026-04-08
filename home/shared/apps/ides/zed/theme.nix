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

  # Workaround for stylix issue #2267:
  # force unsupported `appearance: "unspecified"` to `"dark"` for zed.
  home.activation.zedFixStylixAppearance = lib.hm.dag.entryAfter ["linkGeneration"] ''
    theme_file="${"$"}{XDG_CONFIG_HOME:-${"$"}HOME/.config}/zed/themes/stylix.json"
    if [ -e "${"$"}theme_file" ]; then
      # If stylix linked a read-only store file, replace link with a writable copy.
      if [ -L "${"$"}theme_file" ]; then
        cp --remove-destination "$(readlink -f "${"$"}theme_file")" "${"$"}theme_file"
      fi

      # Replace any unsupported zed value with a valid one.
      sed -i 's/"appearance":[[:space:]]*"unspecified"/"appearance":"dark"/g' "${"$"}theme_file"
    fi
  '';
}
