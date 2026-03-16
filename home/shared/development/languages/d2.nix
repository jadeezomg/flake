{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- D2 (diagram language) ---
    d2
  ];
}
