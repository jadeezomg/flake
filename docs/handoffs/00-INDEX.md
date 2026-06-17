# Mini agent-hub / monitoring — handoff index

Context for all tasks below. Read this first, then the per-task file.

## The system
- Repo: `~/.dotfiles/flake` (NixOS flake). Active host **mini** = Minisforum MS-01, headless.
- GPUs: **Arc Pro B50** (`xe` driver, `/dev/dri/card0`, ~15 GiB — the LLM/compute GPU) + Iris Xe (`i915`, card1, display).
- Tailnet: **`mini.quokka-qilin.ts.net`**. Firewall trusts **only `tailscale0`** (`modules/nixos/networking.nix`); only `:22` is public. Services bind loopback and are fronted by `tailscale serve` (HTTPS), or bind `0.0.0.0` and are tailnet-gated.
- Ports: vLLM **8000**, open-webui **8080**→443, honcho **8100**, beszel **8090**.
- Services live in `hosts/mini/services/`. Toggles in `hosts/mini/host.nix`: `miniLlmHosting`, `miniLlmBackend` (`vllm`|`llamacpp`), shared contract `miniLlm{ServedName="local-chat",Port=8000,Host}`, `miniMemoryHosting`, `miniMonitoring`.

## Plan & status
- Master plan: **`docs/hosts/mini-agent-memory-plan.md`** (architecture, phases, model-routing tiers: local for background/simple, OpenRouter for complex).
- Done & deployed: `services/` refactor, **honcho** (Phase 1, working), **beszel** (server+services+containers+disk).
- Recent commits: `4399ac3 beszel`, `23a277b honcho agent beszel`, `fca4b52 firewall fix`.

## Working conventions (important)
- Deploy from any host: **`just mini deploy`** (pulls origin/main on mini + `nh switch`). Also `just mini pull`, `just mini deploy-dry`, `just mini llm <status|logs|bench|...>`. Commit + **push** first — `deploy` pulls origin.
- Both your shell and mini's are **nushell**. For remote commands use `ssh mini 'bash -lc "…"'`. **Avoid unquoted `()` in echo** inside `bash -lc` (breaks parsing — bitten repeatedly).
- After editing `.nix`: `flake fmt`, `git add`, then `nix eval ".#nixosConfigurations.mini.config.system.build.toplevel.drvPath"` to catch errors before deploy. The `options.json … without a proper context` warning is benign.
- Secrets: sops; user strongly prefers broker/keyring over env. `environmentFile` pattern (declare `sops.secrets."x" = {}` + `lib.optional (config.sops.secrets ? "x")`).

## Tasks (one file each)
1. ~~`01-beszel-gpu-deploy.md` — deploy + verify the staged nvtop GPU change.~~ **Done** (deployed + verified on mini; doc removed). Also added `cap_perfmon` wrappers for `btop`/`gputop` in `gpu-intel.nix`.
2. `02-honcho-llm-finalize.md` — per-feature LLM endpoints + embeddings.
3. `03-hermes-phase2.md` — hermes-agent: local↔OpenRouter routing + honcho memory.
4. `04-shared-honcho-mcp-phase3.md` — honcho MCP across hosts + migrate MEMORY.md.
5. `05-nixflix-phase4.md` — media stack (blocked on decisions).
6. `06-pin-honcho-image.md` — pin the honcho image digest.
