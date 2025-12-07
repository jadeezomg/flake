{ config, pkgs, ... }:

{
  # X server configuration (required for GDM and XWayland compatibility)
  # GNOME uses Wayland by default, but X server is needed for:
  # - GDM display manager
  # - XWayland (for running X11 applications)
  services = {
    xserver = {
      enable = true;
      # Configure keyboard layout (works for both Wayland and X11)
      xkb = {
        layout = "us";
        variant = "euro";
      };
    };
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };
}
