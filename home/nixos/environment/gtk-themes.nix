{pkgs, config, ...}: {
  # GTK themes
  home.packages = with pkgs; [
    kanagawa-gtk-theme
  ];

  # Keep legacy GTK4 theme behavior explicit for HM < 26.05.
  gtk.gtk4.theme = config.gtk.theme;
}
