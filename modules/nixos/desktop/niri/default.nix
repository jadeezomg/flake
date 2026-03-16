{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
    ./dms.nix
  ];

  # Niri Wayland Compositor Configuration (sodiboo/niri-flake)
  # GDM will automatically detect Niri session at login screen
  # You can choose between GNOME and Niri at the login screen

  # Enable Niri Wayland compositor (niri-unstable from niri-flake)
  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  # Create wayland session files for GDM to detect Niri
  # This allows selecting Niri at the login screen
  environment.etc."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=Start Niri Wayland Compositor
    Exec=${config.programs.niri.package}/bin/niri
    Type=Application
    DesktopNames=niri
  '';

  environment.systemPackages = with pkgs; [
    # Niri installed via programs.niri; xwayland-satellite for X11 apps
    # XWayland support - Niri 25.08+ automatically integrates with xwayland-satellite
    # Just install it and ensure it's in PATH (which systemPackages does)
    # Niri will spawn it on-demand when X11 clients connect
    # See: https://github.com/YaLTeR/niri/wiki/Xwayland
    xwayland-satellite
    # wl-clipboard - Automatically installed by DMS when enableClipboard = true
    # mako - Replaced by DMS built-in notification system
    # grim - Optional: Niri has built-in screenshots, but grim useful for advanced workflows
    # slurp - Optional: Used with grim for region selection, or other tools
  ];
}
