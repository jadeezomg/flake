# Task 3 — Phase 2: hermes-agent (local↔OpenRouter routing)

**State:** flake input `hermes-agent` (`github:NousResearch/hermes-agent`) imported in `hosts/mini/default.nix`; `hosts/mini/services/hermes.nix` enables the gateway with Matrix/Telegram/MCP deps. Native systemd mode.

## Goal
Configure hermes model routing:
- **Model routing**: default to the **local** chat stack (`http://127.0.0.1:8000/v1`, served id `local-chat` = `host.miniLlmServedName`) for simple/background; route **complex** tasks to **OpenRouter**. hermes supports per-task model switching (`hermes model` / `/model provider:model`).
- **MCP**: wire the MCP servers hermes should use.

## Notes / gotchas
- hermes config schema is settled on first run — iterate against upstream docs (hermes-agent.nousresearch.com/docs/user-guide/configuration) and `hermes setup`/`hermes config set`.
- Keys via sops in `hermes.env` (declared in `hermes.nix`). Needs `OPENROUTER_API_KEY` and any provider creds.

## Decision required
- **Which OpenRouter model(s)** for the complex tier?

## Suggested skills
- `grill-with-docs` — pin the hermes config/routing design against the domain before coding, then implement. `secrets-structure` skill for the sops wiring.
