{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- LLM Gui / Server ---
    lmstudio # Currently marked as broken, but keeping in NixOS-only config

    # --- LLM Engine ---
    vllm
  ];

  home.file.".claude/skills/dotfiles-tools" = {
    source = ../../../.claude/skills/dotfiles-tools;
    recursive = true;
  };
}
