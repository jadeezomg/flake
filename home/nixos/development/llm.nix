{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    # --- LLM Gui / Server ---
    lmstudio # Currently marked as broken, but keeping in NixOS-only config
  ];
}
