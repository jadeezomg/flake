# Installs global skills under ~/.agents/skills; ~/.claude/skills symlinks there.
# Repo project skills live in the flake's .agents/skills/; .claude/skills symlinks there.
#
# Upstream: pinned `skills-mattpocock` flake input (mattpocock/skills).
# Local overrides: `data/agents/skills/local/` (same skill name wins).
# Opt-outs: `data/agents/skills/.upstream-ignore`.
{
  config,
  dotfilesLib,
  inputs,
  lib,
  ...
}:
let
  skills = dotfilesLib.agentSkills {
    inherit
      lib
      inputs
      dotfilesLib
      ;
  };

  agentsSkillsDir = "${config.home.homeDirectory}/.agents/skills";
  claudeSkillsLink = config.lib.file.mkOutOfStoreSymlink agentsSkillsDir;

  flakeRoot = config.dotfiles.flakeRoot;
in
{
  home.file = skills.homeFiles // {
    ".claude/skills" = {
      source = claudeSkillsLink;
      force = true;
    };
  };

  # Repo: .claude/skills → .agents/skills (project skills live in .agents/skills/).
  home.activation.linkFlakeProjectSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${flakeRoot}/.claude"
    $DRY_RUN_CMD ln -snf ../.agents/skills "${flakeRoot}/.claude/skills"
  '';
}
