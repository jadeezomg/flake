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
# the *local* vLLM tier (http://host.containers.internal:8000/v1, qwen3.5-9b).
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
  ...
}: let
  network = "honcho";
  apiPort = 8100; # 8000 = vLLM, 8080 = open-webui
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

    # Deriver → local vLLM (background tier). vLLM runs no auth, so the key is a
    # placeholder honcho's openai transport simply forwards.
    LLM_OPENAI_API_KEY = "sk-no-auth";
    DERIVER_ENABLED = "true";
    DERIVER_MODEL_CONFIG__TRANSPORT = "openai";
    DERIVER_MODEL_CONFIG__MODEL = "qwen3.5-9b";
    DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL = "http://host.containers.internal:8000/v1";
  };

  containerCommon = {
    inherit image;
    environment = honchoEnv;
    # Optional secrets (OpenRouter key, real provider creds) once Phase 2 lands.
    environmentFiles = lib.optional (config.sops.secrets ? "honcho/env") config.sops.secrets."honcho/env".path;
    extraOptions = [
      "--network=${network}"
      "--add-host=host.containers.internal:host-gateway"
    ];
  };
in {
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # User-defined podman network so containers resolve each other by name
  # (the default bridge has no DNS). `--ignore` makes this idempotent.
  systemd.services.honcho-network = {
    description = "Create the honcho podman network";
    after = ["network.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.virtualisation.podman.package}/bin/podman network create --ignore ${network}";
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
      volumes = ["honcho-pgdata:/var/lib/postgresql/data"];
      cmd = ["postgres" "-c" "max_connections=200"];
      extraOptions = ["--network=${network}"];
    };

    honcho-redis = {
      image = "docker.io/redis:7-alpine";
      extraOptions = ["--network=${network}"];
    };

    honcho-api =
      containerCommon
      // {
        entrypoint = "sh";
        cmd = ["docker/entrypoint.sh"];
        dependsOn = ["honcho-db" "honcho-redis"];
        # Loopback only; tailscale serve fronts it with TLS on the tailnet.
        ports = ["127.0.0.1:${toString apiPort}:8000"];
      };

    honcho-deriver =
      containerCommon
      // {
        # Runs the image's bundled venv python directly (matches upstream compose).
        entrypoint = "/app/.venv/bin/python";
        cmd = ["-m" "src.deriver"];
        dependsOn = ["honcho-db" "honcho-redis" "honcho-api"];
      };
  };

  # Order the container units after the network exists.
  systemd.services.podman-honcho-db.after = ["honcho-network.service"];
  systemd.services.podman-honcho-db.requires = ["honcho-network.service"];
  systemd.services.podman-honcho-redis.after = ["honcho-network.service"];
  systemd.services.podman-honcho-redis.requires = ["honcho-network.service"];

  # HTTPS on the tailnet at :8100 (mirrors the open-webui serve unit).
  systemd.services.tailscale-serve-honcho = {
    description = "Tailscale Serve: HTTPS -> Honcho";
    after = ["tailscaled.service" "podman-honcho-api.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscale}/bin/tailscale serve --bg --https=${toString apiPort} http://127.0.0.1:${toString apiPort}";
      ExecStop = "${tailscale}/bin/tailscale serve --https=${toString apiPort} off";
    };
  };
}
