{
  config,
  pkgs,
  lib,
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

  # Framework 13 specific hardware configuration
  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = true;

  # Framework 13 fingerprint reader configuration
  environment.systemPackages = with pkgs; [
    fprintd # Fingerprint reader daemon
  ];

  # Enable bluetooth (Framework laptop has bluetooth hardware)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Enable fingerprint reader service
  services.fprintd = {
    enable = true;
  };

  # Configure PAM to use fingerprint authentication
  # Use mkForce to override GDM's default fprintAuth = false
  security.pam.services = {
    # Enable fingerprint authentication for login (GDM)
    login.fprintAuth = lib.mkForce true;
    # Enable fingerprint authentication for sudo
    sudo.fprintAuth = true;
    # Enable fingerprint authentication for GDM (GNOME Display Manager)
    gdm-password.fprintAuth = lib.mkForce true;
    # Enable fingerprint authentication for GNOME lock screen
    gdm-fingerprint.fprintAuth = lib.mkForce true;
  };

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
