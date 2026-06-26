# gh CLI config, live-symlinked from the repo (mkOutOfStoreSymlink) so that
# `gh` edits and repo edits stay in sync without a rebuild, and the
# prdiff -> diffnav alias is reproducible across hosts. Same pattern as the
# television cable channels.
{config, ...}: let
  inherit
    (config.lib.dotfiles)
    mkLiveSymlink
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  ghConfig = "${flakeRoot}/modules/profiles/devenv/gh/config.yml";
in {
  xdg.configFile."gh/config.yml" = mkLiveSymlink ghConfig;
}
