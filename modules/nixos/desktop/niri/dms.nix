{
  config,
  pkgs,
  inputs,
  ...
}: {
  # DankMaterialShell (DMS) - Using NixOS module
  # See: https://danklinux.com/docs/dankmaterialshell/nixos
  # Note: xdg.configFile is handled in home/nixos/desktop/dms.nix (Home Manager module)
  programs.dms-shell = {
    enable = true;
    quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
    # Core features
    enableSystemMonitoring = true; # System monitoring widgets (dgop)
    enableVPN = true; # VPN management widget
    enableDynamicTheming = true; # Wallpaper-based theming (matugen)
    enableAudioWavelength = true; # Audio visualizer (cava)
    enableCalendarEvents = true; # Calendar integration (khal)
  };

  programs.dsearch = {
    enable = true;

    # Systemd service configuration
    systemd = {
      enable = true; # Enable systemd user service
      target = "default.target"; # Start with user session
    };
  };
}
