# Home wifi ("Yukikaze"), declared rather than left as mutable NetworkManager
# state. Applies to every host that carries a radio — today framework and mini.
{
  config,
  lib,
  ...
}:
let
  ssid = "Yukikaze";

  # The access point (an AVM FRITZ!Box mesh) runs WPA2 and WPA3 at the same
  # time, so both profiles below share one pre-shared key.
  mkProfile =
    {
      id,
      priority,
      security,
    }:
    {
      connection = {
        inherit id;
        type = "wifi";
        autoconnect = true;
        autoconnect-priority = priority;
      };
      wifi = {
        mode = "infrastructure";
        inherit ssid;
      };
      wifi-security = security // {
        psk = "$YUKIKAZE_PSK";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
in
{
  config = lib.mkIf config.dotfiles.hardware.wireless.enable {
    # Wifi never displaces a wired link: NetworkManager's default route metrics
    # already prefer ethernet (100) over wifi (600). On mini this is a fallback
    # path only — at a DHCP address, so reach it over Tailscale, not the
    # `mini` ssh alias, which is pinned to the static LAN address.
    networking.networkmanager.ensureProfiles = {
      # envsubst substitutes $YUKIKAZE_PSK at activation, so the pre-shared key
      # never reaches the world-readable Nix store.
      environmentFiles = [ config.sops.templates."networkmanager-yukikaze.env".path ];

      profiles = {
        "Yukikaze" = mkProfile {
          id = "Yukikaze";
          priority = 10;
          security.key-mgmt = "sae";
        };

        # WPA2 fallback. Kept because one BSSID dropped with `reason=15`
        # mid-roam under SAE during testing. PMF is off on purpose: that is
        # what makes this a pure WPA2 path, distinct from the SAE profile.
        "Yukikaze-fallback" = mkProfile {
          id = "Yukikaze-fallback";
          priority = -10;
          security = {
            key-mgmt = "wpa-psk";
            proto = "rsn";
            pmf = 1;
          };
        };
      };
    };

    systemd.services.NetworkManager-ensure-profiles.restartTriggers = [
      config.sops.templates."networkmanager-yukikaze.env".content
    ];

    sops = {
      secrets.yukikaze_psk.key = "wifi/yukikaze_psk";
      templates."networkmanager-yukikaze.env" = {
        mode = "0400";
        content = ''
          YUKIKAZE_PSK=${config.sops.placeholder.yukikaze_psk}
        '';
      };
    };
  };
}
