# Task 3 — Phase 2: hermes-agent (local↔OpenRouter routing + honcho memory)

**State:** flake input `hermes-agent` (`github:NousResearch/hermes-agent`) already imported in `hosts/mini/default.nix`; **`hosts/mini/services/hermes.nix` is a stub** (`services.hermes-agent.enable = true; settings = {}`). Native systemd mode.

## Goal
Configure hermes per the plan (`docs/hosts/mini-agent-memory-plan.md` §Phase 2):
- **Model routing**: default to the **local** chat stack (`http://127.0.0.1:8000/v1`, served id `local-chat` = `host.miniLlmServedName`) for simple/background; route **complex** tasks to **OpenRouter**. hermes supports per-task model switching (`hermes model` / `/model provider:model`).
- **Memory**: enable Honcho dialectic user modeling, `HONCHO_URL=https://mini.quokka-qilin.ts.net:8100` (or `http://127.0.0.1:8100` on-host).
- **MCP**: wire the MCP servers hermes should use (incl. the shared honcho MCP from Task 4 once it exists).

## Notes / gotchas
- hermes config schema is settled on first run — iterate against upstream docs (hermes-agent.nousresearch.com/docs/user-guide/configuration) and `hermes setup`/`hermes config set`. Treat `settings = {}` as TBD like the honcho first-run approach.
- hermes can **import OpenClaw `MEMORY.md`/`USER.md`** on first setup — coordinate with Task 4 (don't double-migrate).
- Keys via sops **`hermes/env`** (`environmentFiles` already wired in `hermes.nix` via `lib.optional (config.sops.secrets ? "hermes/env")`; the `sops.secrets."hermes/env"` declaration is commented out — uncomment + add to `secrets/secrets.yaml`). `secrets/SCHEMA.md` documents this secret. Needs `OPENROUTER_API_KEY` + any provider/honcho creds.

## Decision required (open in the plan)
- **Which OpenRouter model(s)** for the complex tier?

## Suggested skills
- `grill-with-docs` — pin the hermes config/routing design against the domain before coding, then implement. `secrets-structure` skill for the sops wiring.
