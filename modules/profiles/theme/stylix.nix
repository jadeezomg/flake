# Theme baseline (HM half) — Stylix with the Birds-of-Paradise base16 scheme
# and CLI/terminal theming. Always pushed (the server keeps shell colors);
# GUI payload (wallpaper, cursor, opacity, GTK, …) lives in ./gui.nix.
{
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
{
  stylix = {
    enable = true;
    autoEnable = true;
    overlays.enable = false;
    polarity = "dark";

    # Single source: lib/theme-base16.nix, derived from lib/theme-palette.nix.
    base16Scheme = dotfilesLib.themeBase16;

    # Single source: lib/theme-fonts.nix (shape matches `stylix.fonts`).
    fonts = dotfilesLib.themeFonts { inherit pkgs; };

    targets = {
      vscode.enable = false;
      firefox.enable = false;
      kitty = {
        enable = true;
        fonts.enable = false;
      };
      ghostty.fonts.enable = false;
      # GTK/dconf theming needs a graphical session; ./gui.nix turns it on
      # (plain priority beats this mkDefault) for theme.gui hosts.
      gtk.enable = lib.mkDefault false;
    };
  };
}
