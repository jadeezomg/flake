{config, ...}: let
  flakeRoot = config.dotfiles.flakeRoot;
  agentsFile = "${flakeRoot}/data/agents/global/AGENTS.md";
  link = config.lib.file.mkOutOfStoreSymlink agentsFile;
in {
  home.file = {
    "AGENTS.md".source = link;
    ".codex/AGENTS.md".source = link;
    ".claude/CLAUDE.md".source = link;
    ".config/agents/AGENTS.md".source = link;
    ".pi/agent/AGENTS.md".source = link;
  };
}
