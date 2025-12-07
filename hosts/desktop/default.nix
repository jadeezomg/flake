{
  config,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}:

let
  host = hostData.hosts.${hostKey} or { };
  userConfig = host.user or { };
in
{
  imports = [
    ./hardware-configuration.nix
    # Shared modules (work on both NixOS and Darwin)
    ../../modules/shared
    # NixOS-specific modules
    ../../modules/nixos
  ];

  # Define user account. Don't forget to set a password with 'passwd'.
  users.users.${user} = {
    isNormalUser = true;
    description = userConfig.description or "user account";
    extraGroups = userConfig.extraGroups or [ "wheel" ];
    shell = pkgs.nushell;
    packages = with pkgs; userConfig.packages or [ ];
  };

  # Desktop host specific configuration
  # TODO: Add desktop-specific hardware-configuration.nix if needed

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
}
