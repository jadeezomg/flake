# Dispatcher implementation lives in lib/nono-profiles.nix.
{
  lib,
  osConfig,
  pkgs,
  pkgs-small,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
  nonoAgents = import ../../../../lib/nono-profiles.nix {inherit pkgs pkgs-small;};
in
  lib.mkIf agentsEnabled {
    home.packages = [nonoAgents.agent];
  }
