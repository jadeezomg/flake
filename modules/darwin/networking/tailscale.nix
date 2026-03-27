# Tailscale on macOS via nix-darwin: runs `tailscaled` as a launchd daemon and
# installs the `tailscale` CLI (see upstream nix-darwin module).
#
# After rebuild, authenticate with: sudo tailscale up
# For Tailscale SSH (equivalent to NixOS `extraUpFlags = [ "--ssh" ]`):
#   sudo tailscale up --ssh
{...}: {
  services.tailscale.enable = true;
}
