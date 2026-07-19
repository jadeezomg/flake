# AGENT SKILLS

## Purpose

Global-install agent skills: upstream from pinned `skills-mattpocock` and `skills-ponytail`, local overrides in `local/`.

## Use skills

- `agent-structure` — project-only `.agents/skills/` vs global-install `data/agents/skills/`, installed copies, and agent config wiring.

## Local hazards

- Upstream skills are **not** vendored here — they install from the flake inputs on `just switch`.
- Edit overrides only under `data/agents/skills/local/`; project-only skills belong in `.agents/skills/`.
- Do not edit installed copies under `~/.agents/skills/` (`~/.claude/skills` symlinks there).
- Opt out of upstream skills via `data/agents/skills/.upstream-ignore` (one skill name per line).
- Refresh the upstream pin with `just update`.
