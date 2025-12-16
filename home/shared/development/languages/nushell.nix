{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Nushell ---
    nufmt # Nushell formatter
    nu_scripts # Nushell scripts and themes
  ];
}
