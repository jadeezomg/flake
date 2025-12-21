{
  config,
  pkgs,
  ...
}: {
  # General system services can be configured here
  # Hardware-related services (audio, printing) are in modules/hardware/
  # Host-specific services should be in hosts/<hostname>/default.nix

  # Enable upower for battery/power management
  # Required for Noctalia shell battery and power features
  services.upower.enable = true;

  # Enable power-profiles-daemon for power management
  # Required for Noctalia shell power-profile feature
  # Framework already has this enabled, but enabling here for all hosts
  services.power-profiles-daemon.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
