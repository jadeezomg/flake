{config, ...}: let
  inherit
    (config.lib.dotfiles)
    mkLiveSymlink
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  agentsFile = "${flakeRoot}/data/agents/global/AGENTS.md";
  agentsLink = config.lib.file.mkOutOfStoreSymlink agentsFile;

  claudeSettingsFile = "${flakeRoot}/data/agents/global/settings.json";
  claudeSettingsLink = config.lib.file.mkOutOfStoreSymlink claudeSettingsFile;

  ompConfigFile = "${flakeRoot}/data/agents/omp/config.yml";
  ompThemeFile = "${flakeRoot}/data/agents/omp/themes/birds-of-paradise.json";
  # Honcho shared-memory injector — auto-discovered from the omp hooks dir.
  ompHonchoHook = "${flakeRoot}/data/agents/omp/hooks/honcho-context.ts";
in {
  home.file = {
    "AGENTS.md".source = agentsLink;
    ".codex/AGENTS.md".source = agentsLink;
    ".claude/CLAUDE.md".source = agentsLink;
    ".config/agents/AGENTS.md".source = agentsLink;
    ".pi/agent/AGENTS.md".source = agentsLink;

    ".claude/settings.json".source = claudeSettingsLink;

    ".omp/agent/config.yml" = mkLiveSymlink ompConfigFile;
    ".omp/agent/themes/birds-of-paradise.json" = mkLiveSymlink ompThemeFile;
    ".omp/agent/hooks/honcho-context.ts" = mkLiveSymlink ompHonchoHook;
  };
}
