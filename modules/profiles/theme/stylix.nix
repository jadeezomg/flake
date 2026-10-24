# Theme baseline (HM half) — Stylix with the Birds-of-Paradise base16 scheme
# and CLI/terminal theming. Always pushed (the server keeps shell colors);
# GUI payload (wallpaper, cursor, opacity, GTK, …) lives in ./gui.nix.
{
  config,
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
    };
  };
}
