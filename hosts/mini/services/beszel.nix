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
#   2. Write the hub's pubkey to KEY_FILE and add the system in the UI
#      (host 127.0.0.1, port 45876). Either do it in the UI's "Add System" dialog
#      (copy the key), or via the API:
#        key=$(curl -H "Authorization: <admin-jwt>" \
#          http://127.0.0.1:8090/api/beszel/getkey | jq -r .key)
#        printf '%s' "$key" | sudo tee /var/lib/beszel-agent/hub_key.pub
#   The agent unit has ConditionPathExists on that file, so it stays inactive
#   (not failed) until the key is present — a switch before onboarding won't error.
{
  config,
  lib,
  pkgs,
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
    # GPU monitoring: the Arc Pro B50 uses the `xe` driver, which does NOT expose
    # the i915 PMU that `intel_gpu_top` needs ("Failed to detect engines"). nvtop
    # reads xe GPUs via fdinfo/sysfs, so use it as the collector instead.
    extraPath = [pkgs.nvtopPackages.intel];
    environment = {
      # Hub + agent are co-located on mini, so use the classic SSH path: the agent
      # listens on :45876 and the hub (registered system 127.0.0.1:45876) connects
      # in, authenticated by the hub's pubkey in KEY_FILE.
      KEY_FILE = "${agentDir}/hub_key.pub";
      # Monitor podman containers via the docker-compat socket (enabled by the
      # devenv containers profile). Harmless if the socket is absent.
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      # Force the nvtop collector (auto-detect would pick the broken intel_gpu_top).
      GPU_COLLECTOR = "nvtop";
    };
  };

  # nvtop needs to read /dev/dri/card0 (the B50, root:video 0660). The agent runs
  # as a dynamic user in `podman disk` (set by the module for container + SMART
  # monitoring); add `video`+`render` so it can open the GPU nodes. mkForce keeps
  # the full set since the same serviceConfig key is set by the module.
  systemd.services.beszel-agent.serviceConfig.SupplementaryGroups =
    lib.mkForce ["podman" "disk" "video" "render"];

  # Skip the agent until onboarding has dropped the hub pubkey, so a deploy before
  # onboarding leaves the unit inactive (condition unmet) rather than failed —
  # which previously made `switch` exit non-zero.
  systemd.services.beszel-agent.unitConfig.ConditionPathExists = "${agentDir}/hub_key.pub";

  # The agent's StateDirectory (${agentDir}) is created by its systemd unit with
  # the right ownership; onboarding drops hub_key.pub there.

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
