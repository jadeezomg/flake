# Television cable channels (TOML under ./cable/), symlinked into ~/.config/television/cable/
# so `tv <channel>` matches upstream layout — same idea as navi cheats under ./navi/cheats/.
{config, ...}: let
  inherit
    (config.lib.dotfiles)
    mkLiveSymlink
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  justRecipes = "${flakeRoot}/modules/profiles/essentials/utils/television/cable/just-recipes.toml";
in {
  xdg.configFile."television/cable/just-recipes.toml" = mkLiveSymlink justRecipes;
}
