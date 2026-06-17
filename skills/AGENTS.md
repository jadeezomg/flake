# PROJECT SKILLS

## Purpose

Project-only skills for this repository.

## Use skills

- `agent-structure` — project-only root `skills/` vs global-install `data/agents/skills/`.

## Local hazards

- Use `skills/<name>/SKILL.md` only for skills that make sense inside this flake.
- Use `data/agents/skills/<category>/<name>/SKILL.md` only for skills that should install globally.
- Do not put repo-specific structure, workflow, or policy skills under `data/agents/skills/` unless they should follow the user into every repo.
- Keep `SKILL.md` concise; add sibling reference files only when needed.

## Structure skills

- `module-structure` — `modules/profiles/**` profile/app layout.
- `flake-structure` — top-level flake layout outside profiles.
- `agent-structure` — root `skills/`, global `data/agents/`, and installed agent config.
- `secrets-structure` — SOPS/age secret layout and wiring.
- `theme-structure` — shared palette and app theme generation.
- `llm-hosting` — mini's local LLM serving: backends, models, context/KV, embeddings, ops.
