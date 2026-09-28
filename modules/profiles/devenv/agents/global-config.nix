{ config, dotfilesLib, ... }:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    ;

  # Live checkout paths, not store copies: editing AGENTS.md or settings.json
  # must take effect without a rebuild.
  agentFiles = dotfilesLib.agentDataFiles config.dotfiles.flakeRoot;

  agentsLink = config.lib.file.mkOutOfStoreSymlink agentFiles.globalAgentsMd;
  claudeSettingsLink = config.lib.file.mkOutOfStoreSymlink agentFiles.claudeSettings;
in
{
  home.file = {
    "AGENTS.md".source = agentsLink;
    ".codex/AGENTS.md".source = agentsLink;
    ".claude/CLAUDE.md".source = agentsLink;
    ".config/agents/AGENTS.md".source = agentsLink;
    ".pi/agent/AGENTS.md".source = agentsLink;

    ".claude/settings.json".source = claudeSettingsLink;

    ".omp/agent/config.yml" = mkLiveSymlink agentFiles.ompConfig;
    ".omp/agent/themes/birds-of-paradise.json" = mkLiveSymlink agentFiles.ompTheme;
  };
}
