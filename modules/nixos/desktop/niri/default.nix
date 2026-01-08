{pkgs, ...}: {
  # Niri Wayland Compositor Configuration
  # GDM will automatically detect Niri session at login screen
  # You can choose between GNOME and Niri at the login screen

  # Enable Niri Wayland compositor
  programs.niri = {
    enable = true;
  };

  # Create wayland session files for GDM to detect Niri
  # This allows selecting Niri at the login screen
  environment.etc."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=Start Niri Wayland Compositor
    Exec=${pkgs.niri}/bin/niri
    Type=Application
    DesktopNames=niri
  '';

  environment.systemPackages = with pkgs; [
    # Niri utilities
    niri # Wayland compositor (required)
    # wl-clipboard - Automatically installed by DMS when enableClipboard = true
    # mako - Replaced by DMS built-in notification system
    # grim - Optional: Niri has built-in screenshots, but grim useful for advanced workflows
    # slurp - Optional: Used with grim for region selection, or other tools
  ];
}
