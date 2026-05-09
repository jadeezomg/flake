# Installs the `agent` dispatcher binary on PATH. Usage:
#
#   agent claude [args...]   → invoke Claude Code in its nono sandbox
#   agent pi [args...]       → invoke pi-coding-agent in its nono sandbox
#   agent ls                 → list available agents
#   agent --help
#
# Per-agent identity (claude-jadee, pi-jadee) and broker credentials are
# applied automatically. Implementation lives in lib/nono-profiles.nix —
# this module just installs the dispatcher derivation.
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
