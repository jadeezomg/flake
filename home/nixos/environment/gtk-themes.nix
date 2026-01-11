{pkgs, ...}: {
  # GTK themes
  home.packages = with pkgs; [
    kanagawa-gtk-theme
  ];
}
