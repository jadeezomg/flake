{pkgs-unstable, ...}: {
  home.packages = [
    # --- 1Password ---
    # pkgs._1password-gui
    # pkgs-unstable._1password-gui-beta # NOTE: Required for now since wayland clipboard is in Beta version
    pkgs-unstable._1password-gui # NOTE: Current 8.11 follows unstable
    pkgs-unstable._1password-cli
  ];
}
