# Dispatcher implementation lives in lib/nono-profiles.nix.
{
  dotfilesLib,
  pkgs,
  pkgs-small,
  ...
}: let
  nonoAgents = dotfilesLib.nonoProfiles {inherit pkgs pkgs-small;};
in {
  home.packages = [nonoAgents.agent];
}
