# Dispatcher implementation lives in lib/nono-profiles.nix.
{
  pkgs,
  pkgs-small,
  ...
}: let
  nonoAgents = import ../../../../lib/nono-profiles.nix {inherit pkgs pkgs-small;};
in {
  home.packages = [nonoAgents.agent];
}
