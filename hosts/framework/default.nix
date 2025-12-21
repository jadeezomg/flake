{
  config,
  pkgs,
  lib,
  hostData,
  hostKey,
  user,
  inputs,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
in {
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    ../../modules/shared
    ../../modules/nixos
  ];

  hardware = {
    graphics.enable = true;
    bluetooth.enable = true;
  };

  environment.systemPackages = with pkgs; [
    fprintd
  ];

  services = {
    fprintd.enable = true;
    power-profiles-daemon.enable = true;
    fwupd. enable = true;
    blueman.enable = true;
    xserver.videoDrivers = ["amdgpu"];
  };

  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    gdm-password.fprintAuth = lib.mkForce true;
    gdm-fingerprint.fprintAuth = lib.mkForce true;
  };

  # System state version - host specific, don't change, it's used by home-manager to determine the initial version of the system.
  system.stateVersion = "25.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  maintenance.garbageCollection = {
    enable = true;
    schedule = "weekly";
    deleteOlderThan = "30d";
  };
}
