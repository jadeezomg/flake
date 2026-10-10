---
name: nix-tracing
description: Trace Determinate Nix evaluations, builds, and substitutions with OpenTelemetry (OTLP). Use when a `flake build`/switch, eval, or cache fetch is slow or stalls and you need to see where the time goes, or when adding persistent `otlp*` Nix settings.
---

# Nix tracing

Determinate Nix (3.23.0 and later) exports OpenTelemetry traces over OTLP `http/json`. Tracing is off until an endpoint is set. Each Nix command gives one trace. The root span has the command name (`nix build`). Child spans follow the progress tree: `Build`, `Substitute`, `QueryPathInfo`, `CopyPath`, `FileTransfer`, `FetchTree`, `EvaluateFlakeDerivationOutput`. The span attributes `nix.drv.name` and `nix.store.name` hold the package name without the hash.

Docs: <https://docs.determinate.systems/determinate-nix/opentelemetry>.

## Where traces go

- NixOS hosts (`desktop`, `framework`, `mini`) always send every Nix command, client and daemon, to Tempo on mini (`modules/nixos/nix-tracing.nix` → `http://mini:4318` over the tailnet). The user views them in Grafana at <https://grafana.jadee.fyi>. Retention is 60 days (`hosts/mini/services/tracing.nix`).
- To read one trace yourself, get its ID from `NIX_DEBUG_OTEL=1` and query Tempo on mini, which listens on loopback only: `ssh mini curl -s http://127.0.0.1:3200/api/v2/traces/<trace-id>`.
- `caya` (Darwin, work machine) has no tailnet and no persistent setting. Use the local procedure below there. `otel-desktop-viewer` is installed on every host through the devenv profile.

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

- NixOS: `nix.settings` in `modules/nixos/nix-tracing.nix`. The Determinate module writes it to `/etc/nix/nix.custom.conf`.
- Darwin: `determinateNix.customSettings` in `modules/darwin/nix.nix`. `nix.settings` has no effect there. caya stays without a setting: keep its traces local.
- Keys: `otlp = true`, `otlp-endpoint = "<base URL>"` (no `/v1/traces`, no trailing slash).
- The daemon does not see your shell environment, and it ignores `otlp*` options that clients send. Daemon-side spans come only from these files.
- `OTEL_EXPORTER_OTLP_ENDPOINT` overrides `otlp-endpoint` for the client process. That is how a local run on a NixOS host goes to a local receiver instead of mini.

## Tokens

A hosted backend needs an `authorization` header. Never put a token in `otlp-headers` in Nix configuration: the value goes into the world-readable Nix store. For one run, use `OTEL_EXPORTER_OTLP_HEADERS` from a secret in the environment. For the daemon, run a local collector that holds the token, or deliver a root-only `/etc/nix/otlp.conf` through SOPS (`secrets-structure`) and `!include` it.
