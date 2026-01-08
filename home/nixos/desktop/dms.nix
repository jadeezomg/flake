{
  config,
  pkgs-unstable,
  inputs,
  ...
}: {
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
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
}
