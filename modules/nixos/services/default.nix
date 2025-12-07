{ config, pkgs, ... }:

{
  # General system services can be configured here
  # Hardware-related services (audio, printing) are in modules/hardware/
  # Host-specific services should be in hosts/<hostname>/default.nix

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
