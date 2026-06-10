# SSH client destinations for `programs.ssh.matchBlocks` (home-manager).
# Adjust hostName values to match your LAN / Tailscale naming.
{
  destinations = {
    framework = {
      hostName = "framework";
      user = "jadee";
    };
    desktop = {
      hostName = "desktop";
      user = "jadee";
    };
    mini = {
      hostName = "192.168.178.100";
      user = "jadee";
    };
    unraid = {
      hostName = "192.168.178.62";
      user = "root";
    };
  };
}
