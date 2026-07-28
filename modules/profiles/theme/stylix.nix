# Theme baseline (HM half) — Stylix with the Birds-of-Paradise base16 scheme
# and CLI/terminal theming. Always pushed (the server keeps shell colors);
# GUI payload (wallpaper, cursor, opacity, GTK, …) lives in ./gui.nix.
{
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  # Palette single source: lib/theme-palette.nix (via dotfilesLib).
  themeColors = dotfilesLib.palette;
in
{
  stylix = {
    enable = true;
    autoEnable = true;
    overlays.enable = false;
    polarity = "dark";

    # Custom base16 scheme from the palette
    base16Scheme = {
      scheme = "Birds of Paradise";
      author = "Jeroen de Vries";
      base00 = themeColors.bg-primary;
      base01 = themeColors.bg-secondary;
      base02 = themeColors.bg-tertiary;
      base03 = themeColors.sidebar-border;
      base04 = themeColors.text-tertiary;
      base05 = themeColors.text-primary;
      base06 = themeColors.text-secondary;
      base07 = themeColors.text-secondary;
      base08 = themeColors.text-primary;
      base09 = themeColors.ansi-yellow;
      base0A = themeColors.accent-yellow;
      base0B = themeColors.ansi-green;
      base0C = themeColors.ansi-cyan;
      base0D = themeColors.ansi-blue;
      base0E = themeColors.ansi-magenta;
      base0F = themeColors.accent-red;
    };

    fonts = {
      sizes.applications = 10;
      monospace = {
        package = pkgs.nerd-fonts.iosevka;
        name = "Iosevka Nerd Font";
      };
      serif = {
        package = pkgs.iosevka-etoile;
        name = "Iosevka Etoile";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter Display";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

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
