# Dispatcher implementation lives in lib/nono-profiles.nix.
{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
  nonoAgents = import ../../../../lib/nono-profiles.nix {inherit pkgs;};
in
  lib.mkIf agentsEnabled {
    home.packages = [nonoAgents.agent];
  }
