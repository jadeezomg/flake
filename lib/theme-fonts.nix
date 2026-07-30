# Font selections — single source for the three places that need them:
# Stylix's HM theme baseline, the `fonts` profile's package list (so the fonts
# Stylix names are guaranteed installed), and the GDM greeter's dconf profile
# (the greeter gets none of the user's HM config).
#
# Shape matches `stylix.fonts` so the HM side can assign it wholesale.
#
# apply: { pkgs }
{ pkgs }:
{
  sizes.applications = 10;

  monospace = {
    package = pkgs.nerd-fonts.iosevka;
    name = "Iosevka Nerd Font";
  };
  serif = {
    package = pkgs.iosevka-etoile; # local package via overlay
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
}
