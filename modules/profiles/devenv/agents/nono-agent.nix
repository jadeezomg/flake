# Dispatcher implementation lives in lib/nono-profiles.nix.
{
  dotfilesLib,
  pkgs,
  ...
}:
let
  nonoAgents = dotfilesLib.nonoProfiles { inherit pkgs; };
in
{
  home.packages = [ nonoAgents.agent ];
}
