{
  pkgs,
  pkgs-stable,
  ...
}: {
  home.packages = with pkgs; [
    # --- LLM Gui / Server ---
    lmstudio # Currently marked as broken, but keeping in NixOS-only config

    # --- LLM Engine ---
    # Unstable vllm (e.g. 0.16) can fail against nixpkgs torch (at::cpu::L2_cache_size); stable tracks a matching pair.
    pkgs-stable.vllm
    # vllm # currently broken
  ];

  home.file.".claude/skills/dotfiles-tools" = {
    source = ../../../.claude/skills/dotfiles-tools;
    recursive = true;
  };
}
