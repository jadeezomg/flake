{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    firewalld # Firewall management
    firewalld-gui # Firewall GUI
    networkmanager # Network manager
    networkmanagerapplet # Network manager applet
    wireguard-tools # Wireguard tools
    wireguard-ui # Wireguard UI
    protonvpn-gui # ProtonVPN GUI
    openresolv # Openresolv for NetworkManager
  ];
}
