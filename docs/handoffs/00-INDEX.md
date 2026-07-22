# Mini agent-hub / monitoring — handoff index

Context for all tasks below. Read this first, then the per-task file.

## The system
- Repo: `~/.dotfiles/flake` (NixOS flake). Active host **mini** = Minisforum MS-01, headless.
- GPUs: **Arc Pro B50** (`xe` driver, `/dev/dri/card0`, ~15 GiB — the LLM/compute GPU) + Iris Xe (`i915`, card1, display).
- Tailnet: **`mini.quokka-qilin.ts.net`**. Firewall trusts **only `tailscale0`** (`modules/nixos/networking.nix`); only `:22` is public. Services bind loopback and are fronted by Caddy `tsnet` (HTTPS), or bind `0.0.0.0` and are tailnet-gated.
- Ports: LLM chat **8000**, open-webui **8080**, beszel **8090**.
- Services live in `hosts/mini/services/`. Toggles in `hosts/mini/host.nix`: `miniLlmHosting`, `miniLlmBackend` (`vllm`|`llamacpp`), shared contract `miniLlm{ServedName="local-chat",Port=8000,Host}`, `miniMonitoring`, `miniMediaHosting`.

## Plan & status
- Done & deployed: `services/` refactor, **beszel** (server+services+containers+disk), local LLM stack (llama.cpp backend), nixflix media.
- Honcho shared-memory (ADR-0002) was withdrawn and removed from the flake (2026-07-22).

## Working conventions (important)
- Deploy from any host: **`just mini deploy`** (pulls origin/main on mini + `nh switch`). Also `just mini pull`, `just mini deploy-dry`, `just mini llm <status|logs|bench|...>`. Commit + **push** first — `deploy` pulls origin.
- Both your shell and mini's are **nushell**. For remote commands use `ssh mini 'bash -lc "…"'`. **Avoid unquoted `()` in echo** inside `bash -lc` (breaks parsing — bitten repeatedly).
- After editing `.nix`: `flake fmt`, `git add`, then `nix eval ".#nixosConfigurations.mini.config.system.build.toplevel.drvPath"` to catch errors before deploy. The `options.json … without a proper context` warning is benign.
- Secrets: sops; user strongly prefers broker/keyring over env. `environmentFile` pattern (declare `sops.secrets."x" = {}` + `lib.optional (config.sops.secrets ? "x")`).

## Tasks (one file each)
1. ~~`01-beszel-gpu-deploy.md` — deploy + verify the staged nvtop GPU change.~~ **Done** (deployed + verified on mini; doc removed). Also added `cap_perfmon` wrappers for `btop`/`gputop` in `gpu-intel.nix`.
2. `03-hermes-phase2.md` — hermes-agent: local↔OpenRouter routing.
3. ~~`05-nixflix-phase4.md` — media stack.~~ **Done** — see [`docs/hosts/mini-media.md`](../hosts/mini-media.md) + ADRs 0003–0006.
