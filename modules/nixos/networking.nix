{
  config,
  host,
  lib,
  pkgs,
  ...
}: let
  serverProfile = config.dotfiles.profiles.server.enable;
in {
  networking.hostName = host.hostname or "nixos";
  networking.networkmanager.enable = true;

  # --- Tailscale (mesh VPN + SSH) ---
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = ["--ssh"];
  };

  # Server hosts use NixOS's built-in nftables-backed firewall; desktop hosts keep
  # firewalld (the GUI app expects it).
  networking.firewall = lib.mkIf serverProfile {
    enable = true;
    allowedTCPPorts = [22];
    trustedInterfaces = ["tailscale0"];
  };

  environment.systemPackages = with pkgs;
    [
      # --- Network management ---
      networkmanager
      openresolv

      # --- VPN clients ---
      wireguard-tools

      # --- Wireless ---
      wirelesstools

      # --- Network filesystems ---
      nfs-utils
      samba

      # --- Tailscale CLI ---
      tailscale
    ]
    ++ lib.optionals (!serverProfile) [
      # --- GUI / desktop-only network tooling ---
      networkmanagerapplet
      firewalld
      firewalld-gui
      proton-vpn
      wireguard-ui
    ];
}
