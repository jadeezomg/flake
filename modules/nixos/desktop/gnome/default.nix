{pkgs, ...}: {
  # GNOME Desktop Environment Configuration
  services = {
    desktopManager.gnome.enable = true;
  };
}
