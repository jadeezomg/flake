# Variants of the Birds-of-Paradise palette. A host picks one with
# dotfiles.profiles.theme.variant. Home Manager modules read the result as
# config.dotfiles.theme.palette (lib/home/theme.nix).
#
# Each variant starts from the canonical palette in ./theme-palette.nix and
# replaces only the keys it lists.
#
# apply: { palette }
{ palette }:
{
  # The canonical palette: dark brown main background.
  brown = palette;

  # Near-black main background. Everything else stays brown.
  black = palette // {
    # Warm black: a very dark brown-black #110c0b
    bg-primary = "#110c0b";
    # Other near-blacks to try:
    # bg-primary = "#0d0d0d"; # Neutral black #0d0d0d
    # bg-primary = "#080808"; # Deepest black, for OLED screens #080808
    # bg-primary = "#18181a"; # Greyish black #18181a
  };
}
