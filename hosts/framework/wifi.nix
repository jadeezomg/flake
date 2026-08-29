{ config, ... }:
{
  # Home wifi, declared rather than left as mutable NetworkManager state.
  #
  # The access point ("Yukikaze", an AVM FRITZ!Box mesh) runs WPA2 and WPA3 at
  # the same time. SAE works on this MT7922 card, so the primary profile uses
  # it. The WPA2 profile stays as a lower-priority fallback: one BSSID dropped
  # with `reason=15` mid-roam during testing, and WPA2 is the proven path back.
  #
  # `ensureProfiles` writes keyfiles to /run/NetworkManager/system-connections.
  # It does NOT overwrite mutable profiles in /etc — remove those by UUID once
  # this lands, or NetworkManager shows each network twice.
  networking.networkmanager.ensureProfiles = {
    # envsubst substitutes $YUKIKAZE_PSK at activation, so the pre-shared key
    # never reaches the world-readable Nix store.
    environmentFiles = [ config.sops.templates."networkmanager-yukikaze.env".path ];

    profiles = {
      "Yukikaze" = {
        connection = {
          id = "Yukikaze";
          type = "wifi";
          autoconnect = true;
          autoconnect-priority = 10;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "Yukikaze";
        };
        wifi-security = {
          key-mgmt = "sae";
          psk = "$YUKIKAZE_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

      "Yukikaze-fallback" = {
        connection = {
          id = "Yukikaze-fallback";
          type = "wifi";
          autoconnect = true;
          autoconnect-priority = -10;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "Yukikaze";
        };
        # PMF is disabled here on purpose: it is what makes this a pure WPA2
        # path, distinct from the SAE profile above.
        wifi-security = {
          key-mgmt = "wpa-psk";
          proto = "rsn";
          pmf = 1;
          psk = "$YUKIKAZE_PSK";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };

  systemd.services.NetworkManager-ensure-profiles.restartTriggers = [
    config.sops.templates."networkmanager-yukikaze.env".content
  ];

  sops = {
    secrets.yukikaze_psk.key = "framework/wifi/yukikaze_psk";
    templates."networkmanager-yukikaze.env" = {
      mode = "0400";
      content = ''
        YUKIKAZE_PSK=${config.sops.placeholder.yukikaze_psk}
      '';
    };
  };
}
