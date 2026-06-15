# Beszel — lightweight server + service + container monitoring (hub + agent).
#
# Native nixpkgs services (no containers). The agent collects mini's system
# metrics, systemd service status, podman container stats, and disk SMART, and
# connects *outbound* to the local hub (HUB_URL) using the hub's ssh pubkey
# (KEY_FILE) + a universal token (TOKEN_FILE) — the model from nixpkgs'
# nixos/tests/beszel.nix. The hub dashboard is exposed on the tailnet via
# `tailscale serve` (HTTPS), like the other mini UIs.
#
# FIRST-RUN ONBOARDING (one-time; PocketBase always needs an admin):
#   1. Open https://mini.quokka-qilin.ts.net:8090 and create the superuser.
#   2. Populate the agent's key + token from the hub API (or use `just`/ssh):
#        token=$(curl -H "Authorization: <admin-jwt>" \
#          http://127.0.0.1:8090/api/beszel/universal-token | jq -r .token)
#        key=$(curl   -H "Authorization: <admin-jwt>" \
#          http://127.0.0.1:8090/api/beszel/getkey        | jq -r .key)
#        printf '%s' "$key"   | sudo tee ${agentDir}/hub_key.pub
#        printf '%s' "$token" | sudo tee ${agentDir}/token
#        sudo chown beszel-agent: ${agentDir}/{hub_key.pub,token}
#      then add the system (host 127.0.0.1, port 45876) in the hub UI.
#   Until those files exist the agent simply retries connecting (no crash loop).
{
  config,
  ...
}: let
  hubPort = 8090; # 8000 vLLM, 8080 webui, 8100 honcho
  agentDir = "/var/lib/beszel-agent";
  tailscale = config.services.tailscale.package;
in {
  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1"; # tailscale serve fronts it with TLS
    port = hubPort;
  };

  services.beszel.agent = {
    enable = true;
    # Disk SMART monitoring (adds the agent to the disk group).
    smartmon.enable = true;
    environment = {
      # Outbound connection to the local hub; no inbound port needed.
      HUB_URL = "http://127.0.0.1:${toString hubPort}";
      KEY_FILE = "${agentDir}/hub_key.pub";
      TOKEN_FILE = "${agentDir}/token";
      # Monitor podman containers via the docker-compat socket (enabled by the
      # devenv containers profile). Harmless if the socket is absent.
      DOCKER_HOST = "unix:///run/podman/podman.sock";
    };
  };

  # The agent's StateDirectory (${agentDir}) is created by its systemd unit with
  # the right ownership; onboarding drops hub_key.pub + token there.

  # HTTPS dashboard on the tailnet at :8090 (same pattern as open-webui/honcho).
  systemd.services.tailscale-serve-beszel = {
    description = "Tailscale Serve: HTTPS -> Beszel hub";
    after = ["tailscaled.service" "beszel-hub.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscale}/bin/tailscale serve --bg --https=${toString hubPort} http://127.0.0.1:${toString hubPort}";
      ExecStop = "${tailscale}/bin/tailscale serve --https=${toString hubPort} off";
    };
  };
}
