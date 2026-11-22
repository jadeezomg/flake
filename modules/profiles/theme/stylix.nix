# Theme baseline (HM half) — Stylix with the Birds-of-Paradise base16 scheme
# and CLI/terminal theming. Always pushed (the server keeps shell colors);
# GUI payload (wallpaper, cursor, opacity, GTK, …) lives in ./gui.nix.
{
  config,
  dotfilesLib,
  lib,
  options,
  pkgs,
  ...
}:
let
  # nixpkgs dropped wayprompt (unmaintained upstream); Home Manager's stub now
  # only asserts if `programs.wayprompt` is defined. Stylix's auto-enabled
  # target still defines it, so it has to stay off. Stylix is removing the
  # target in nix-community/stylix#2557 (issue #2556), which replaces it with a
  # `mkRemovedOptionModule` stub at this exact path that errors if still set.
  # A live target's `enable` is a bool option; the stub's type is `unspecified`,
  # so this flips false when the PR lands and the entry disappears (with a
  # warning) instead of erroring.
  waypromptTarget =
    let
      enableOption = lib.attrByPath [ "stylix" "targets" "wayprompt" "enable" ] null options;
    in
    enableOption != null && (enableOption.type.name or "") == "bool";
in
{
  stylix = {
    enable = true;
    autoEnable = true;
    overlays.enable = false;
    polarity = "dark";

    # The palette follows the host's variant (lib/home/theme.nix).
    base16Scheme = dotfilesLib.mkThemeBase16 config.dotfiles.theme.palette;

    fonts = dotfilesLib.themeFonts { inherit pkgs; };

    targets = {
      vscode.enable = false;
      firefox.enable = false;
      kitty = {
        enable = true;
        fonts.enable = false;
      };
      ghostty.fonts.enable = false;
      # Not installed anywhere; autoEnable would still theme it and warn.
      rofi.enable = false;
      # GTK/dconf theming needs a graphical session; ./gui.nix turns it on
      # (plain priority beats this mkDefault) for theme.gui hosts.
      gtk.enable = lib.mkDefault false;
    }
    //
      lib.warnIf (!waypromptTarget)
        ''
          modules/profiles/theme/stylix.nix needs re-checking: Stylix no longer has a
          wayprompt target. Delete the wayprompt entry in stylix.nix.
        ''
        (
          lib.optionalAttrs waypromptTarget {
            # Stylix still themes wayprompt, which nixpkgs no longer ships.
            wayprompt.enable = false;
          }
        );
  };
}
