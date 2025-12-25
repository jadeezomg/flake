{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Julia ---
    julia
  ];
}
