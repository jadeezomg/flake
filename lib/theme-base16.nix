# Birds-of-Paradise as a base16 scheme, derived from the canonical palette.
#
# Shared because Stylix has to be configured twice on Linux GUI hosts: the HM
# half themes user apps, and the NixOS half is the only thing that can reach
# system-level surfaces — most notably the GDM greeter, whose colours live in
# gnome-shell's compiled stylesheet rather than in any dconf key.
#
# apply: { palette }
{ palette }:
{
  scheme = "Birds of Paradise";
  author = "Jeroen de Vries";
  variant = "dark";
  base00 = palette.bg-primary;
  base01 = palette.bg-secondary;
  base02 = palette.bg-tertiary;
  base03 = palette.sidebar-border;
  base04 = palette.text-tertiary;
  base05 = palette.text-primary;
  base06 = palette.text-secondary;
  base07 = palette.text-secondary;
  base08 = palette.text-primary;
  base09 = palette.ansi-yellow;
  base0A = palette.accent-yellow;
  base0B = palette.ansi-green;
  base0C = palette.ansi-cyan;
  base0D = palette.ansi-blue;
  base0E = palette.ansi-magenta;
  base0F = palette.accent-red;
}
