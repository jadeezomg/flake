# lazygit config, live-symlinked from the repo (mkOutOfStoreSymlink) so that
# repo edits apply on the next lazygit start without a rebuild. Same pattern
# as the gh config. lazygit itself and glow install from ../tools.nix.
{ config, ... }:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  lazygitConfig = "${flakeRoot}/modules/profiles/devenv/lazygit/config.yml";
in
{
  xdg.configFile."lazygit/config.yml" = mkLiveSymlink lazygitConfig;
}
