{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- LLM Gui / Server ---
    lmstudio # Currently marked as broken, but keeping in NixOS-only config
  ];
}
