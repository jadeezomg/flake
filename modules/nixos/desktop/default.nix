{pkgs, ...}: {
  imports = [
    ./gnome
    ./niri
  ];

  # Shared desktop configuration
  # X server configuration (required for GDM and XWayland compatibility)
  # GNOME uses Wayland by default, but X server is needed for:
  # - GDM display manager
  # - XWayland (for running X11 applications)

  # Apply Mutter experimental-features (e.g. fractional scaling) system-wide so GDM
  # uses the same settings as the user session. Otherwise monitors.xml can become
  # incompatible and break the login screen layout. See GDM bug 1028.
  # https://gitlab.gnome.org/GNOME/gdm/-/issues/1028
  programs.dconf.enable = true;
  # programs.dconf.profiles.user.databases = [
  #   {
  #     settings = {
  #       "org/gnome/mutter" = {
  #         experimental-features = ["scale-monitor-framebuffer"];
  #       };
  #     };
  #   }
  # ];

  services = {
    displayManager.gdm.enable = true;
    gvfs.enable = true; # Mount, trash, etc
    tumbler.enable = true; # Thumbnail support for images
    xserver = {
      enable = true;
      # Configure keyboard layout (works for both Wayland and X11)
      xkb = {
        layout = "us";
        variant = "euro";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libnotify # Desktop notifications
    nautilus # File manager
  ];
}
