{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    # --- LLM Gui / Server ---
    lmstudio
  ];
}
