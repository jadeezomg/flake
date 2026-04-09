{
  pkgs,
  ...
}: {
  # GTK themes
  home.packages = with pkgs; [
    kanagawa-gtk-theme
  ];

  gtk.gtk4.theme = null;
}
