# Mini — Agent & Shared-Memory Hub (plan)

Turn **mini** into the home-lab's agent + memory hub: a local model backend, a
**shared memory server** every agent on every host talks to over Tailscale, an
autonomous agent runtime, and (independently) a media stack. Services are grouped
under `hosts/mini/services/`.

Status: **Phase 1 in progress.** Phases 2–4 are designed but not built.

## Architecture

```
                    mini  (tailnet hub — services firewalled to tailscale0 only)
  ┌──────────────────────────────────────────────────────────────────────┐
  │ vLLM-XPU :8000        local model backend (Qwen3.5-9B int4, OpenAI API)│
  │ open-webui :8080      chat UI (HTTPS via `tailscale serve`)            │
  │ honcho  :8100   NEW   shared memory (FastAPI + Postgres); deriver→local│
  │ hermes-agent          autonomous agent: model→routed, memory→honcho    │
  │ nixflix         NEW   Jellyfin + arr media stack (independent)         │
  └──────────────────────────────────────────────────────────────────────┘
        ▲ HONCHO_URL=http://mini:8100   ·   honcho MCP over tailscale
        │
   Claude Code · opencode · hermes · pi · …  on framework/desktop/caya
        → one shared memory, one local model, one OpenRouter budget
```

All HTTP services bind the tailnet and are kept off the public internet by
`networking.firewall.trustedInterfaces = ["tailscale0"]` (only `:22` is public).
UIs get HTTPS via `tailscale serve`; raw APIs stay plain-HTTP on the tailnet
(WireGuard already encrypts transport).

## Model routing — local vs OpenRouter

Two tiers, chosen per task by cost/latency/quality:

| Tier | Backend | Use for |
|------|---------|---------|
| **Local** | mini vLLM (`http://mini:8000/v1`, Qwen3.5-9B int4) | Simple, high-volume, background, latency-tolerant: honcho's background deriver, summarization, classification, routine agent steps, anything that should be **free and private**. |
| **Remote** | **OpenRouter** (`https://openrouter.ai/api/v1`, strong models) | Complex reasoning, long-horizon agentic work, code, tool-use that needs a frontier model. |

Principles:
- **Background and bulk work runs local** — the GPU is already paid for and the
  data stays on the tailnet. honcho's deriver points at the local vLLM.
- **Complex/interactive work routes to OpenRouter** — hermes (and any agent that
  supports model switching) picks an OpenRouter model for hard tasks.
- `OPENROUTER_API_KEY` lives in **sops** (per the broker/keyring preference), fed
  to services via `environmentFile`, never inlined in the Nix store.

## Phase 1 — Honcho memory server  ◄ current

`hosts/mini/services/honcho.nix`:
- Honcho is FastAPI + Postgres, Docker-first, AGPL-3.0, not in nixpkgs → run the
  upstream image via **`virtualisation.oci-containers`** (podman backend, matching
  the existing podman setup) against a **native `services.postgresql`** so NixOS
  owns the database and backups.
- Listen on **`:8100`** (8000/8080 are taken), tailnet-only via `trustedInterfaces`.
- **Deriver LLM = local vLLM** (background task → local tier). Honcho's
  `LLM_*`/provider env points at `http://127.0.0.1:8000/v1`, model `qwen3.5-9b`.
- Secrets (any provider keys, DB URL) via **sops** `environmentFile`.
- Optional later: `tailscale serve` HTTPS for the honcho dashboard.

## Phase 2 — hermes-agent

Fill the `hosts/mini/services/hermes.nix` stub:
- **Model routing**: default to local vLLM; switch to an **OpenRouter** model for
  complex tasks (hermes supports per-task model selection).
- **Memory**: enable Honcho dialectic user modeling, `HONCHO_URL=http://mini:8100`.
- **MCP**: wire the tools/servers hermes should use.
- Keys (`OPENROUTER_API_KEY`, Honcho, provider creds) via sops `hermes/env`.

## Phase 3 — shared agent integration

- Add a **honcho MCP server** entry to the shared agent config under
  `data/agents/` so Claude Code, opencode, pi, etc. on **every** host point at
  `http://mini:8100` over tailscale → one shared memory.
- Optionally migrate the existing Claude `MEMORY.md` into honcho (honcho/OpenClaw
  migration is non-destructive).

## Phase 4 — nixflix media stack (independent)

- Add the `nixflix` input (+ its `vpn-confinement` input), enable
  `nixosModules.default`, configure Jellyfin + the arr services.
- Separate workstream with its own decisions: media storage location on mini
  (disko layout), VPN provider for the torrent/arr path, indexers, and
  reverse-proxy/serve exposure. Revisit whether the media stack belongs on the
  LLM box or a different host.

## Open decisions

1. **hermes model split** — which OpenRouter model(s) for the complex tier?
2. **Which agents** get the honcho MCP wired in (Claude Code only, or opencode/pi/cursor too)?
3. **nixflix** — host it on mini at all, and where does media storage live?
