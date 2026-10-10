---
name: nix-tracing
description: OpenTelemetry tracing in this flake — Determinate Nix evaluations, builds, and substitutions, plus mini's Tempo/Grafana stack and its traced services (hermes-agent, open-webui, Caddy). Use when a `flake build`/switch, eval, cache fetch, hermes turn, or chat.jadee.fyi request is slow or fails and you need to see where the time goes, or when changing `otlp*` Nix settings or Tempo.
---

# Nix tracing

Determinate Nix (3.23.0 and later) exports OpenTelemetry traces over OTLP `http/json`. Tracing is off until an endpoint is set. Each Nix command gives one trace. The root span has the command name (`nix build`). Child spans follow the progress tree: `Build`, `Substitute`, `QueryPathInfo`, `CopyPath`, `FileTransfer`, `FetchTree`, `EvaluateFlakeDerivationOutput`. The span attributes `nix.drv.name` and `nix.store.name` hold the package name without the hash.

Docs: <https://docs.determinate.systems/determinate-nix/opentelemetry>.

## Where traces go

- NixOS hosts (`desktop`, `framework`, `mini`) always send every Nix command, client and daemon, to Tempo on mini (`modules/nixos/nix-tracing.nix` → `http://mini:4318` over the tailnet). The user views them in Grafana at <https://grafana.jadee.fyi>. Retention is 60 days (`hosts/mini/services/tracing.nix`).
- To read one trace yourself, get its ID from `NIX_DEBUG_OTEL=1` and query Tempo on mini, which listens on loopback only: `ssh mini curl -s http://127.0.0.1:3200/api/v2/traces/<trace-id>`.
- `caya` (Darwin, work machine) has no tailnet and no persistent setting. Use the local procedure below there. `otel-desktop-viewer` is installed on every host through the devenv profile.

## Service traces on mini

`hosts/mini/services/tracing.nix` owns the whole stack and the service integrations. All of it is gated by `miniTracing` in `hosts/mini/host.nix`.

- Tempo receivers: OTLP/HTTP `0.0.0.0:4318` (tailnet only, through the firewall) and OTLP/gRPC `127.0.0.1:4317` (loopback). Caddy and open-webui use gRPC. Nix and hermes use HTTP.
- `hermes-agent`: the `hermes_otel` plugin, pinned by tag, enters through `services.hermes-agent.extraPlugins`. Its OpenTelemetry packages go on the unit's `PYTHONPATH`, because hermes cannot lazy-install into the Nix store. Spans hold whole prompts and responses. `max_attribute_bytes = 131072` keeps Tempo from cutting them at 2 KB.
- `open-webui`: built-in OTel. Only the environment variables are set.
- `caddy`: `tracing` in the shared `tsnet` snippet (`services/caddy.nix`) gives one span per request. Caddy sends `traceparent` to the backend, so a proxied request and its backend spans form one trace.
- In Grafana Explore, filter on `service.name`: `nix`, `nix-daemon`, `hermes-agent`, `open-webui`, `caddy`.

## Trace one run locally

1. Look for a receiver that already runs: `ss -ltnp | grep -E ':431[89]'`. The user often keeps `otel-desktop-viewer` open on 4318 (UI on <http://localhost:8000>). Leave it running.
2. If you must read the spans yourself, start a collector on port 4319. Its `debug` exporter writes the spans as text to a log that you can grep:

   ```yaml
   # otel.yaml (put it in the scratchpad)
   receivers:
     otlp:
       protocols:
         http:
           endpoint: localhost:4319
   exporters:
     debug:
       verbosity: detailed
   service:
     telemetry:
       metrics:
         level: none # 8888 is taken by otel-desktop-viewer
     pipelines:
       traces:
         receivers: [otlp]
         exporters: [debug]
   ```

   `nix run nixpkgs#opentelemetry-collector -- --config otel.yaml > otel.log 2>&1` (run it in the background). Wait for `Everything is ready` in the log.
3. Ask the user to run the build with the endpoint. Builds and switches are the user's job (root `AGENTS.md`):
   `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4319 NIX_DEBUG_OTEL=1 flake build`
   `NIX_DEBUG_OTEL=1` prints the trace ID on stderr. You can trace non-system commands yourself, for example `nix eval` or `nix build --dry-run nixpkgs#<pkg>`.
4. Read the spans: `grep -E 'Name +:|nix\.(drv|store)\.name|Start time|End time' otel.log`. The slowest spans and the failed spans are the result. Stop the collector when you are done.

## Persistent configuration

- NixOS: `/etc/nix/otlp.conf`, pulled in with `!include` from `modules/nixos/nix-tracing.nix`. Keep `otlp*` out of `nix.settings`: the NixOS `nix.conf` check runs `nix config show` in the sandbox, the trace export fails there, and the check fails the build.
- Darwin: `determinateNix.customSettings` in `modules/darwin/nix.nix`. `nix.settings` has no effect there. caya stays without a setting: keep its traces local.
- Keys: `otlp = true`, `otlp-endpoint = "<base URL>"` (no `/v1/traces`, no trailing slash).
- The daemon does not see your shell environment, and it ignores `otlp*` options that clients send. Daemon-side spans come only from these files.
- `OTEL_EXPORTER_OTLP_ENDPOINT` overrides `otlp-endpoint` for the client process. That is how a local run on a NixOS host goes to a local receiver instead of mini.

## Tokens

A hosted backend needs an `authorization` header. Never put a token in `otlp-headers` in Nix configuration: the value goes into the world-readable Nix store. For one run, use `OTEL_EXPORTER_OTLP_HEADERS` from a secret in the environment. For the daemon, run a local collector that holds the token, or deliver a root-only `/etc/nix/otlp.conf` through SOPS (`secrets-structure`) and `!include` it.
