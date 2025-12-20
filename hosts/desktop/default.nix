{
  config,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
in {
  imports = [
    ./hardware-configuration.nix
    # Shared modules (work on both NixOS and Darwin)
    ../../modules/shared
    # NixOS-specific modules
    ../../modules/nixos
  ];

  # Desktop host specific configuration
  hardware = {
    graphics = {
      enable = true;
    };
    nvidia = {
      open = true;
      nvidiaSettings = true;
      modesetting.enable = true;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  # System state version - host specific
  system.stateVersion = "25.11";

  # Nix experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Automatic garbage collection
  maintenance.garbageCollection = {
    enable = true;
    schedule = "weekly";
    deleteOlderThan = "30d";
  };

  # Monitor configuration for GDM
  environment.etc."xdg/monitors.xml" = {
    source = ../../data/hosts/desktop/monitors.xml;
    mode = "0644";
  };
}
