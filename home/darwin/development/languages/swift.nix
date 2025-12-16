{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Swift ---
    swift
    sourcekit-lsp
  ];
}
