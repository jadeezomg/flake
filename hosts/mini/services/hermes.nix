{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  hermesSrc = inputs.hermes-agent;
  haInputs = hermesSrc.inputs;

  hermesAgent = pkgs.callPackage "${hermesSrc}/nix/hermes-agent.nix" {
    inherit (haInputs) uv2nix pyproject-nix pyproject-build-systems;
    npm-lockfile-fix = haInputs.npm-lockfile-fix.packages.${system}.default;
    rev = hermesSrc.rev or null;
  };
in {
  services.hermes-agent = {
    enable = true;
    package = hermesAgent;

    addToSystemPackages = true;
    restart = "always";
    restartSec = 5;

    extraPackages = [
      pkgs.kagi-cli
      pkgs.context7
    ];

    extraDependencyGroups = ["matrix" "web" "messaging" "mcp" "honcho" "edge-tts"];

    # Matrix bot, non-secret half (connects over loopback, no TLS on-box). Auth is by
    # ACCESS TOKEN (MATRIX_ACCESS_TOKEN in hermes.env), not password: password login
    # re-logs in on every restart and rotates the device's identity key, which breaks
    # E2EE one-time keys and cross-signing. Token keeps the device stable. MATRIX_DEVICE_ID
    # is pinned so the cross-signed device + E2EE crypto store persist across restarts.
    environment = {
      MATRIX_HOMESERVER = "http://127.0.0.1:6167";
      MATRIX_USER_ID = "@hermes:matrix.jadee.fyi";
      MATRIX_DEVICE_ID = "hermes-mini";
      MATRIX_E2EE_MODE = "optional";
    };

    environmentFiles = [config.sops.templates."hermes.env".path];
  };

  sops.secrets.openrouter_api_key = {};
  sops.secrets.agent_pat = {};
  sops.secrets.hf_token = {};
  sops.secrets.kagi_session_token.key = "kagi/session_token";
  sops.secrets.context7_api_key = {};
  # Matrix auth is access-token based (see the `environment` note above). The password
  # secret is kept declared (break-glass: used once to mint the token / re-bootstrap via
  # docs/hosts/mini-matrix-hermes-setup.md) but is intentionally NOT put in the env.
  sops.secrets.matrix_hermes_password.key = "matrix/hermes_password";
  sops.secrets.matrix_hermes_access_token.key = "matrix/hermes_access_token";
  sops.secrets.matrix_hermes_recovery_key.key = "matrix/hermes_recovery_key";
  sops.templates."hermes.env" = {
    mode = "0400";
    content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder.openrouter_api_key}
      GITHUB_TOKEN=${config.sops.placeholder.agent_pat}
      HF_TOKEN=${config.sops.placeholder.hf_token}
      KAGI_SESSION_TOKEN=${config.sops.placeholder.kagi_session_token}
      CONTEXT7_API_KEY=${config.sops.placeholder.context7_api_key}
      MATRIX_ACCESS_TOKEN=${config.sops.placeholder.matrix_hermes_access_token}
      MATRIX_RECOVERY_KEY=${config.sops.placeholder.matrix_hermes_recovery_key}
    '';
  };

  systemd.services.hermes-agent.environment.HERMES_MANAGED = lib.mkForce "";
  system.activationScripts.hermes-unmanage = {
    deps = ["hermes-agent-setup"];
    text = ''
      _m="${config.services.hermes-agent.stateDir}/.hermes/.managed"
      [ -e "$_m" ] && ${pkgs.coreutils}/bin/unlink "$_m" || true
    '';
  };

  # ── Dashboard / gateway lifecycle: stop the crash-loop wedge ────────────────
  # The dashboard runs as the same `hermes` user and, on connection changes /
  # webhook+telegram onboarding / its restart button, shells out to
  # `hermes gateway restart`. Hermes' restart only does the clean
  # "SIGUSR1-and-let-the-supervisor-relaunch" dance when it RECOGNISES a systemd
  # unit, found purely by file path: it looks for `${gatewayUnitName}.service`
  # (hermes derives the name from $HERMES_HOME → "hermes-gateway"), NOT our
  # module's `hermes-agent.service`. Not finding one, it falls through to
  # spawning a *detached* `gateway run --replace` inside the dashboard's cgroup,
  # which seizes the gateway lock and kills the systemd gateway — so the
  # hermes-agent unit then crash-loops forever on "Gateway already running".
  #
  # Two-part fix:
  # 1. Alias the unit to the name hermes looks for. Now `hermes gateway restart`
  #    takes the systemd branch; since it's a SYSTEM unit and the dashboard is
  #    non-root, hermes raises "requires root" and exits cleanly (see
  #    `_require_root_for_system_service`) — it NEVER spawns. Wedge eliminated.
  #    (Dashboard gateway start/stop/restart buttons therefore report a benign
  #    "requires root" error; the gateway stays exclusively systemd-owned.)
  # 2. A path unit applies what those buttons no longer can: when the dashboard
  #    writes a new connection secret to `.env`, restart the one true gateway.
  #    Safe from restart loops — the gateway only READS `.env` at startup, never
  #    writes it (secrets are written only by dashboard/`hermes config set`).
  systemd.services.hermes-agent.aliases = ["hermes-gateway.service"];

  systemd.paths.hermes-agent-reload = {
    wantedBy = ["multi-user.target"];
    pathConfig = {
      PathModified = "${config.services.hermes-agent.stateDir}/.hermes/.env";
      Unit = "hermes-agent-reload.service";
    };
  };
  systemd.services.hermes-agent-reload = {
    description = "Restart hermes-agent when its .env (connection secrets) changes";
    serviceConfig = {
      Type = "oneshot";
      # Coalesce rapid multi-key writes from a single dashboard save.
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart hermes-agent.service";
    };
  };
}
