# Nix build tracing: Grafana Tempo stores OpenTelemetry traces from Determinate
# Nix, and Grafana shows them at https://grafana.jadee.fyi.
#
# Tempo 3.0 runs in monolithic mode (no Kafka) with local storage. NixOS hosts
# send to http://mini:4318 (modules/nixos/nix-tracing.nix). Port 4318 listens on
# all interfaces, but the firewall opens it only on tailscale0 (trusted). LAN
# clients cannot reach it. Grafana and Tempo's query API listen on loopback.
#
# Services on mini that send traces to the same Tempo:
#   hermes-agent  hermes_otel plugin (OTLP/HTTP :4318): sessions, LLM calls,
#                 tool calls. Spans carry whole prompts and responses.
#   open-webui    built-in OpenTelemetry (OTLP/gRPC 127.0.0.1:4317).
#   caddy         `tracing` in the shared tsnet snippet (services/caddy.nix),
#                 OTLP/gRPC 127.0.0.1:4317. Caddy sends `traceparent` to the
#                 backend, so a chat.jadee.fyi request and its open-webui spans
#                 are one trace.
#
# FIRST RUN: Grafana starts with admin/admin and asks for a new password at the
# first login. The Tempo data source is provisioned.
#
# Secrets (secrets/secrets.yaml):
#   grafana_secret_key  random key that Grafana uses to sign and encrypt its DB
#                       data. Required: nixpkgs has no default for it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;
  tempoPort = 3200;
  grafanaPort = 3000;
  otlpGrpc = "127.0.0.1:4317";

  # Same interpreter lookup as hermes.nix. The plugin imports OpenTelemetry in
  # the hermes process, and the llm-agents build does not ship it.
  hermesPython = lib.findFirst (
    d: (d.pname or "") == "python3"
  ) null pkgs.llm-agents.hermes-agent.nativeBuildInputs;
  hermesOtelSrc = pkgs.fetchFromGitHub {
    owner = "briancaffey";
    repo = "hermes-otel";
    rev = "hermes-otel-v1.22.1";
    hash = "sha256-vcsbv3203g6D9CUDaaz8hW3IIsxOyRH3yfDSD3wY60w=";
  };
  # extraPlugins needs plugin.yaml at the package root; the repo keeps it in hermes_otel/.
  hermesOtel = pkgs.runCommand "hermes_otel" { } "cp -r ${hermesOtelSrc}/hermes_otel $out";
in
{
  sops.secrets.grafana_secret_key.owner = "grafana";

  services = {
    tempo = {
      enable = true;
      settings = {
        stream_over_http_enabled = true;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = tempoPort;
        };
        distributor = {
          receivers.otlp.protocols = {
            http.endpoint = "0.0.0.0:4318";
            # Caddy can only export over gRPC. Loopback: only mini's services use it.
            grpc.endpoint = otlpGrpc;
          };
          # The 2 KB default cuts the prompts that hermes_otel puts in span attributes.
          max_attribute_bytes = 131072;
        };
        storage.trace = {
          backend = "local";
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/blocks";
        };
        backend_worker.compaction.block_retention = "1440h"; # 60 days
        # A full system build substitutes thousands of paths, and each one adds
        # spans to the same trace. The 5 MB default can cut these traces off.
        overrides.defaults.global.max_bytes_per_trace = 100000000; # 100 MB
        usage_report.reporting_enabled = false;
      };
    };

    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = grafanaPort;
          domain = "grafana.jadee.fyi";
          root_url = "https://grafana.jadee.fyi";
        };
        security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
        analytics.reporting_enabled = false;
      };
      provision.datasources.settings.datasources = [
        {
          name = "Tempo";
          type = "tempo";
          url = "http://127.0.0.1:${toString tempoPort}";
          isDefault = true;
        }
      ];
    };

    caddy.virtualHosts = mkTsnetProxy {
      domain = "grafana.jadee.fyi";
      port = grafanaPort;
    };

    hermes-agent = lib.mkIf config.services.hermes-agent.enable {
      extraPlugins = [ hermesOtel ];
      settings.plugins.enabled = [ "hermes_otel" ];
      environment = {
        OTEL_TEMPO_ENDPOINT = "http://127.0.0.1:4318/v1/traces";
        OTEL_PROJECT_NAME = "hermes-agent";
      };
    };

    open-webui.environment = lib.mkIf config.services.open-webui.enable {
      ENABLE_OTEL = "True";
      ENABLE_OTEL_TRACES = "True";
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://${otlpGrpc}";
      OTEL_EXPORTER_OTLP_INSECURE = "True";
    };
  };

  systemd.services = {
    # Python reads PYTHONPATH at startup, so it goes on the unit, not in hermes's .env.
    hermes-agent.environment.PYTHONPATH = lib.mkIf config.services.hermes-agent.enable (
      hermesPython.pkgs.makePythonPath (
        with hermesPython.pkgs;
        [
          opentelemetry-api
          opentelemetry-sdk
          opentelemetry-exporter-otlp-proto-http
        ]
      )
    );
    # opentelemetry-go reads the standard variables. An http:// URL means no TLS.
    caddy.environment = {
      OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${otlpGrpc}";
      OTEL_SERVICE_NAME = "caddy";
    };
  };
}
