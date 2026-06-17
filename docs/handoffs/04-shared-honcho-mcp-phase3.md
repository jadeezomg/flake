# Task 4 — Phase 3: shared honcho MCP across hosts + migrate MEMORY.md

**State:** not started. honcho is live at `https://mini.quokka-qilin.ts.net:8100` (tailnet, `USE_AUTH=false`).

## Goal
Make **every agent on every host** use the one shared honcho memory over Tailscale:
- Add a **honcho MCP server** entry to the **shared agent config under `data/agents/`** (this flake owns agent config; do NOT edit installed `~/.claude`/`~/.agents` — see the `agent-structure` skill). honcho ships an MCP server (`--transport http`); point it / the SDK at `HONCHO_URL=https://mini.quokka-qilin.ts.net:8100`.
- Wire it for the agents in use: Claude Code, opencode, pi, cursor — **confirm which** (open decision in the plan).
- **Migrate** the existing Claude `MEMORY.md` into honcho. honcho's OpenClaw migration is **non-destructive** (originals kept). Coordinate with Task 3 — hermes can also import `MEMORY.md`; pick one path to avoid duplicates.

## Notes
- Memory layout for this repo lives at `~/.claude/projects/-home-jadee--dotfiles-flake/memory/` (per-fact files + `MEMORY.md` index) — that's the Claude Code auto-memory, separate from honcho. Decide what migrates.
- Source of truth for agent paths: `data/agents/` and the `agent-structure` skill (root `skills/`, global `data/agents/`, installed config).

## Decision required (open in the plan)
- **Which agents** get the honcho MCP wired in.

## Suggested skills
- `agent-structure` (understand the agent config layout first), then implement. `grill-with-docs` if the integration design needs sharpening.
