{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  serverProfile = config.dotfiles.profiles.server.enable;
in
{
  networking = {
    hostName = host.hostname or "nixos";
    networkmanager.enable = true;

    # NixOS nftables firewall everywhere (no firewalld GUI stack).
    # Servers also expose SSH on the LAN; desktops rely on Tailscale SSH.
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = lib.optionals serverProfile [ 22 ];
    };
  };

  # --- Tailscale (mesh VPN + SSH) ---
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--ssh" ];
    extraSetFlags = [ "--operator=jadee" ]; # add
  };

  environment.systemPackages =
    with pkgs;
    [
      # --- Network management ---
      networkmanager
      openresolv

      # --- VPN clients ---
      wireguard-tools

      # (wireless tooling lives in modules/profiles/hardware/wireless.nix)

      # --- Network filesystems ---
      nfs-utils
      samba

      # --- Tailscale CLI ---
      tailscale
    ]
    ++ lib.optionals (!serverProfile) [
      # --- GUI / desktop-only network tooling ---
      networkmanagerapplet
      proton-vpn
      wireguard-ui
    ];
}
