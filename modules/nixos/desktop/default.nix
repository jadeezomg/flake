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
