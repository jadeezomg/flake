{
  config,
  pkgs,
  inputs,
  ...
}: {
  # DankMaterialShell (DMS) - Using flake home-manager module with unstable packages
  # See: https://danklinux.com/docs/dankmaterialshell/nixos-flake
  # Modules are imported in parts/functions/modules.nix
  # The module uses the flake package automatically (built with nixpkgs-unstable)
  # Note: enableClipboard, enableSystemMonitoring, etc. are now built-in and don't need to be set
  programs.dms-shell = {
    enable = true;
    quickshell.package = pkgs.quickshell;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
  };

  programs.dsearch = {
    enable = true;

    # Systemd service configuration
    systemd = {
      enable = true; # Enable systemd user service
      target = "default.target"; # Start with user session
    };
  };

  # Manage Niri configuration files
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
}
