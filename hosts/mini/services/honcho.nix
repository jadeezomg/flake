# Honcho — shared agent-memory server (Phase 1 of docs/hosts/mini-agent-memory-plan.md).
#
# Honcho is a FastAPI service (api + background "deriver") backed by Postgres
# (pgvector) and Redis. It is Docker-first and not in nixpkgs, so we run the
# published image (ghcr.io/plastic-labs/honcho) plus pgvector/redis as a small
# podman stack on a user-defined network. Postgres data persists in a named
# podman volume.
#
# Exposure: the api binds loopback :8100; `tailscale serve` fronts it with HTTPS
# at https://mini.quokka-qilin.ts.net:8100 (same pattern as open-webui), so other
# hosts' agents set HONCHO_URL there. Nothing is published on the public internet.
#
# Model routing (see the plan doc): the deriver is a *background* task, so it uses
# the *local* chat tier (http://host.containers.internal:<miniLlmPort>/v1, served name
# `miniLlmServedName` — see host.nix; same whether vllm or llamacpp is active).
# OpenRouter is reserved for the complex/interactive tier (hermes, Phase 2).
#
# FIRST-RUN ITERATION: honcho sets LLM endpoints *per feature* via
# `<FEATURE>_MODEL_CONFIG__OVERRIDES__BASE_URL`. Only `DERIVER_*` is wired here
# (confirmed from .env.template). On first boot, read the api/deriver logs and the
# honcho config reference (https://honcho.dev/docs) and add the remaining feature
# overrides (dialectic, summary, …) so every reasoning call hits the local vLLM
# rather than falling back to api.openai.com. Embeddings start disabled
# (EMBED_MESSAGES=false) to avoid needing an embedding provider on first boot;
# re-enable later against the local jina embedding instance.
{
  config,
  lib,
  host,
  ...
}:
let
  network = "honcho";
  subnet = "10.89.0.0/24";
  apiPort = 8100; # 8000 = local LLM chat, 8080 = open-webui
  # Local chat contract (host.nix) — same regardless of vllm/llamacpp backend.
  llmPort = host.miniLlmPort;
  llmModel = host.miniLlmServedName;
  image = "ghcr.io/plastic-labs/honcho:latest"; # TODO: pin to a digest once a boot is confirmed
  tailscale = config.services.tailscale.package;

  # Shared env for both honcho processes. Non-secret; real provider keys (e.g.
  # OPENROUTER for Phase 2) go in the optional sops env file below.
  honchoEnv = {
    DB_CONNECTION_URI = "postgresql+psycopg://honcho:honcho@${network}-db:5432/honcho";
    CACHE_URL = "redis://${network}-redis:6379/0?suppress=true";
    CACHE_ENABLED = "true";
    USE_AUTH = "false"; # tailnet-gated, like vLLM
    LOG_LEVEL = "INFO";
    EMBED_MESSAGES = "false"; # see FIRST-RUN note

    # Deriver → local chat server (background tier). It runs no auth, so the key is
    # a placeholder honcho's openai transport simply forwards. Model + port come from
    # the shared contract (host.nix), so the active backend (vllm/llamacpp) is invisible.
    LLM_OPENAI_API_KEY = "sk-no-auth";
    DERIVER_ENABLED = "true";
    DERIVER_MODEL_CONFIG__TRANSPORT = "openai";
    DERIVER_MODEL_CONFIG__MODEL = llmModel;
    DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL = "http://host.containers.internal:${toString llmPort}/v1";
  };

  containerCommon = {
    inherit image;
    environment = honchoEnv;
    # Optional secrets (OpenRouter key, real provider creds) once Phase 2 lands.
    environmentFiles = lib.optional (
      config.sops.secrets ? "honcho/env"
    ) config.sops.secrets."honcho/env".path;
    extraOptions = [
      "--network=${network}"
      "--add-host=host.containers.internal:host-gateway"
    ];
  };
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # honcho's api/deriver containers reach the host's local chat server (:${toString llmPort})
  # across the podman bridge (host.containers.internal). The host firewall only trusts
  # tailscale0, so without this the connection times out. Allow just the honcho
  # subnet → the chat port. iptables backend (nftables is inactive on mini), so this
  # uses extraCommands rather than the nftables-only extraInputRules.
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw -s ${subnet} -p tcp --dport ${toString llmPort} -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -s ${subnet} -p tcp --dport ${toString llmPort} -j nixos-fw-accept || true
  '';

  # User-defined podman network so containers resolve each other by name
  # (the default bridge has no DNS). `--ignore` makes this idempotent.
  systemd.services.honcho-network = {
    description = "Create the honcho podman network";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Pin the subnet so the firewall allow below has a stable CIDR to match.
      ExecStart = "${config.virtualisation.podman.package}/bin/podman network create --ignore --subnet ${subnet} ${network}";
    };
  };

  virtualisation.oci-containers.containers = {
    honcho-db = {
      image = "docker.io/pgvector/pgvector:pg15";
      environment = {
        POSTGRES_USER = "honcho";
        POSTGRES_PASSWORD = "honcho"; # local-only on the podman network; not reachable off-host
        POSTGRES_DB = "honcho";
      };
      volumes = [ "honcho-pgdata:/var/lib/postgresql/data" ];
      cmd = [
        "postgres"
        "-c"
        "max_connections=200"
      ];
      extraOptions = [ "--network=${network}" ];
    };

    honcho-redis = {
      image = "docker.io/redis:7-alpine";
      extraOptions = [ "--network=${network}" ];
    };

    honcho-api = containerCommon // {
      entrypoint = "sh";
      cmd = [ "docker/entrypoint.sh" ];
      dependsOn = [
        "honcho-db"
        "honcho-redis"
      ];
      # Loopback only; tailscale serve fronts it with TLS on the tailnet.
      ports = [ "127.0.0.1:${toString apiPort}:8000" ];
    };

    honcho-deriver = containerCommon // {
      # Runs the image's bundled venv python directly (matches upstream compose).
      entrypoint = "/app/.venv/bin/python";
      cmd = [
        "-m"
        "src.deriver"
      ];
      dependsOn = [
        "honcho-db"
        "honcho-redis"
        "honcho-api"
      ];
    };
  };

  # Order the container units after the network exists.
  systemd.services.podman-honcho-db.after = [ "honcho-network.service" ];
  systemd.services.podman-honcho-db.requires = [ "honcho-network.service" ];
  systemd.services.podman-honcho-redis.after = [ "honcho-network.service" ];
  systemd.services.podman-honcho-redis.requires = [ "honcho-network.service" ];

  # HTTPS on the tailnet at :8100 (mirrors the open-webui serve unit, incl. the
  # Restart=on-failure that rides out tailscaled NoState on boot and the etag race
  # between sibling serve units on a switch — see open-webui.nix for the full why).
  systemd.services.tailscale-serve-honcho = {
    description = "Tailscale Serve: HTTPS -> Honcho";
    after = [
      "tailscaled.service"
      "podman-honcho-api.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = 300;
    startLimitBurst = 30;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscale}/bin/tailscale serve --bg --https=${toString apiPort} http://127.0.0.1:${toString apiPort}";
      ExecStop = "${tailscale}/bin/tailscale serve --https=${toString apiPort} off";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
