{pkgs, ...}: {
  # GNOME Desktop Environment Configuration
  # GDM will automatically detect GNOME session at login screen

  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  environment.systemPackages = with pkgs; [
    libnotify # Desktop notifications
    nautilus # File manager
  ];
}
