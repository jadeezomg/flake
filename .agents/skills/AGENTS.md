# PROJECT SKILLS

## Purpose

Project-only skills for this repository.

## Use skills

- `agent-structure` — project-only `.agents/skills/` vs global-install `data/agents/skills/`.

## Local hazards

- Use `.agents/skills/<name>/SKILL.md` only for skills that make sense inside this flake.
- `.claude/skills` symlinks to `.agents/skills` for Claude Code discovery.
- Use `data/agents/skills/local/` only for skills that should install globally into `~/.agents/skills`.
- Keep `SKILL.md` concise; add sibling reference files only when needed.

## Structure skills

- `module-structure` — `modules/profiles/**` profile/app layout.
- `flake-structure` — top-level flake layout outside profiles.
- `overlays` — `parts/overlays/` and self-expiring workaround overlays.
- `agent-structure` — `.agents/skills/`, global `data/agents/`, and installed agent config.
- `secrets-structure` — SOPS/age secret layout and wiring.
- `theme-structure` — shared palette and app theme generation.
- `xdg-default-apps` — MIME defaults and desktop app ownership.
- `llm-hosting` — mini's local LLM serving: backends, models, context/KV, embeddings, ops.
