{
  config,
  pkgs-unstable,
  inputs,
  hostKey,
  ...
}: let
  # Base niri config (shared across all hosts)
  baseConfig = ./niri/config.kdl;

  # Host-specific output configs
  outputConfigs = {
    framework = ./niri/outputs-framework.kdl;
    desktop = ./niri/outputs-desktop.kdl;
  };

  # Get the host-specific output config, or null if not found
  hostOutputConfig = outputConfigs.${hostKey} or null;

  # Combine base config with host-specific output config
  combinedConfig =
    if hostOutputConfig != null
    then
      pkgs-unstable.writeText "niri-config.kdl" ''
        ${builtins.readFile baseConfig}
        ${builtins.readFile hostOutputConfig}
      ''
    else baseConfig;
in {
  # DankMaterialShell (DMS) - Using flake home-manager module with unstable packages
  # See: https://danklinux.com/docs/dankmaterialshell/nixos-flake
  # Modules are imported in parts/functions/modules.nix
  # The module uses the flake package automatically (built with nixpkgs-unstable)
  # Note: enableClipboard, enableSystemMonitoring, etc. are now built-in and don't need to be set
  programs.dank-material-shell = {
    enable = true;
    # Use quickshell from nixpkgs-unstable
    quickshell.package = pkgs-unstable.quickshell;
    # Use dgop from flake (required by DMS)
    dgop.package = inputs.dgop.packages.${pkgs-unstable.stdenv.hostPlatform.system}.default;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
  };

  # Manage Niri configuration files
  # Combines base config with host-specific output configurations
  xdg.configFile."niri/config.kdl".source = combinedConfig;
}
