{
  config,
  pkgs,
  host,
  ...
}: {
  imports = [
    ./tailscale-client.nix
  ];

  networking.hostName = host.hostname or "nixos";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    # Network management
    networkmanager # Network manager
    networkmanagerapplet # Network manager applet
    openresolv # Openresolv for NetworkManager

    # Firewall management
    firewalld # Firewall management
    firewalld-gui # Firewall GUI

    # VPN management
    wireguard-tools # Wireguard tools
    wireguard-ui # Wireguard UI
    proton-vpn # ProtonVPN GUI
  ];
}
