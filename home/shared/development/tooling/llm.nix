{
  lib,
  osConfig,
  pkgs,
  ...
}:
# LLM agent packages moved to modules/shared/profiles/devenv/llm/agents.nix.
# This HM module wires up the cross-platform bits gated behind the same
# profile toggle:
#   - opencode HM widget
#   - Claude skill symlink (points at flake-root .claude/skills/dotfiles-tools;
#     used to live in home/{nixos,darwin}/development/llm.nix — unified in P9c
#     because both copies were byte-identical except for their relative path).
lib.mkIf (osConfig.dotfiles.profiles.devenv.llm.agents.enable or false) {
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };

  home.file.".claude/skills/dotfiles-tools" = {
    source = ../../../../.claude/skills/dotfiles-tools;
    recursive = true;
  };
}
