{
  host,
  pkgs,
  ...
}: {
  networking.hostName = host.hostname or "nixos";
  networking.networkmanager.enable = true;

  # --- Tailscale (mesh VPN + SSH) ---
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = ["--ssh"];
  };

  environment.systemPackages = with pkgs; [
    # --- Network management ---
    networkmanager
    networkmanagerapplet
    openresolv

    # --- Firewall ---
    firewalld
    firewalld-gui

    # --- VPN clients ---
    wireguard-tools
    wireguard-ui
    proton-vpn

    # --- Wireless ---
    wirelesstools

    # --- Network filesystems ---
    nfs-utils
    samba

    # --- Tailscale CLI ---
    tailscale
  ];
}
