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
    niri # Wayland compositor
    wl-clipboard # Clipboard utilities for Wayland
    mako # Notification daemon for Wayland
    grim # Screenshot utility
    slurp # Screen selection for screenshots
    fuzzel # Fuzzy finder for Wayland
    # Note: Noctalia shell should be configured via home-manager
    # See home-manager configuration for noctalia-shell setup
  ];
}
