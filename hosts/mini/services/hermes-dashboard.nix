# Hermes dashboard — the web UI (sessions, cron, chat, config), served at
# https://hermes.jadee.fyi by the shared Caddy tailnet-node proxy (services/caddy.nix).
#
# It's a SEPARATE process from the gateway (`hermes dashboard`, not `hermes gateway`),
# so we run a second systemd unit as the SAME `hermes` user → it shares the gateway's
# HERMES_HOME (sessions/cron/config). The dashboard server deps (fastapi/uvicorn) come
# from the `web` dependency group on services.hermes-agent (see hermes.nix).
#
# Auth model (important): bound to 127.0.0.1, the dashboard runs in its "trusted
# loopback" mode — it injects its session token into the page, so ANYONE who can
# load the page gets control. We therefore NEVER expose it directly; Caddy is the
# only door, gated with basic_auth (HERMES_DASHBOARD_HASH, a bcrypt hash from sops in
# services/caddy.nix). Caddy rewrites Host→127.0.0.1 so the dashboard's DNS-rebinding
# guard accepts the proxied request. Net: only someone on the tailnet AND past
# basic_auth reaches a machine-control surface.
#
# DNS: add an A record hermes.jadee.fyi → the mini-proxy node IP (the stale unraid
# CNAME for that name must be deleted first — `flake mini dns-sync` will flag it).
{
  config,
  pkgs,
  ...
}: let
  cfg = config.services.hermes-agent;
  # Same package the gateway runs (mirrors the module's effectivePackage), so the
  # `web`/`matrix` extras are present and no extra build is triggered.
  hermesPkg = cfg.package.override {
    inherit (cfg) extraPythonPackages extraDependencyGroups;
  };
  port = 9119; # hermes dashboard default; loopback only
in {
  systemd.services.hermes-dashboard = {
    description = "Hermes Agent Dashboard (web UI)";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "hermes-agent.service"];
    wants = ["network-online.target"];

    environment = {
      HOME = cfg.stateDir;
      HERMES_HOME = "${cfg.stateDir}/.hermes";
      HERMES_MANAGED = "true";
    };

    serviceConfig = {
      User = cfg.user;
      Group = cfg.group;
      WorkingDirectory = cfg.workingDirectory;
      ExecStart = "${hermesPkg}/bin/hermes dashboard --no-open --host 127.0.0.1 --port ${toString port}";
      Restart = "always";
      RestartSec = 5;
      UMask = "0007";
      # Mirror the gateway unit's relaxed sandboxing (it writes HERMES_HOME).
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [cfg.stateDir cfg.workingDirectory];
      PrivateTmp = true;
    };

    path = [hermesPkg pkgs.bash pkgs.coreutils pkgs.git];
  };

  # Front door: tailnet TLS via the shared mini-proxy node, gated by basic_auth.
  # Host→127.0.0.1 satisfies the dashboard's loopback Host guard.
  services.caddy.virtualHosts."hermes.jadee.fyi".extraConfig = ''
    import tsnet
    basic_auth {
      jadee {env.HERMES_DASHBOARD_HASH}
    }
    reverse_proxy 127.0.0.1:${toString port} {
      header_up Host 127.0.0.1
    }
  '';
}
