# Herdr.app (herdr-desktop) theme, built from the host palette variant.
# Herdr reads every file in ~/.config/herdr-app/themes/ and derives the panel
# colors that `colors` does not set. You pick the theme once in the theme
# menu. Herdr saves that choice in the layout file, which it writes itself, so
# this module does not own the layout.
{ config, ... }:
let
  p = config.dotfiles.theme.palette;
in
{
  xdg.configFile."herdr-app/themes/birds-of-paradise.json".text = builtins.toJSON {
    background = p.bg-primary;
    foreground = p.text-primary;
    selection = p.bg-tertiary;
    cursor = p.text-primary;
    ansi = [
      p.ansi-black
      p.ansi-red
      p.ansi-green
      p.ansi-yellow
      p.ansi-blue
      p.ansi-magenta
      p.ansi-cyan
      p.ansi-white
      p.ansi-bright-black
      p.ansi-bright-red
      p.ansi-bright-green
      p.ansi-bright-yellow
      p.ansi-bright-blue
      p.ansi-bright-magenta
      p.ansi-bright-cyan
      p.ansi-bright-white
    ];
    # Same roles as the OMP theme (data/agents/omp/themes/birds-of-paradise.json).
    colors = {
      chrome = p.bg-secondary;
      border = p.sidebar-border;
      accent = p.accent-blue;
      working = p.ansi-yellow;
      blocked = p.ansi-red;
      done = p.ansi-green;
      idle = p.ansi-bright-black;
    };
  };
}
