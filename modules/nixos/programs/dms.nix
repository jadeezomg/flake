{
  config,
  pkgs-unstable,
  inputs,
  ...
}: {
  # DankMaterialShell (DMS) - Using flake NixOS module with unstable packages
  # See: https://danklinux.com/docs/dankmaterialshell/nixos-flake
  # The native module is not in nixpkgs-unstable yet, so we use the flake module
  # Module is imported in parts/hosts.nix
  # All packages are sourced from nixpkgs-unstable via the flake
  programs.dms-shell = {
    enable = true;
    # Use flake package (built with nixpkgs-unstable since flake follows it)
    package = inputs.dankMaterialShell.packages.${pkgs-unstable.stdenv.hostPlatform.system}.default;
    # Use quickshell from nixpkgs-unstable
    quickshell.package = pkgs-unstable.quickshell;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
    enableSystemMonitoring = true;
    enableClipboard = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
  };
}
