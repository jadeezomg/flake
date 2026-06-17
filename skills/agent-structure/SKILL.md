---
name: agent-structure
description: Apply this flake's agent configuration layout rules. Use when editing agent skills, global agent instructions, Claude settings, OMP agent config, or deciding between root skills and data/agents/skills.
---

# Agent Structure

## Scope

Use this for agent-facing files: root `skills/`, `data/agents/**`, installed agent dirs, and agent config wiring.

## Skill locations

- Project-only skills for this repo live in root `skills/<name>/SKILL.md`.
- Global-install skills live in `data/agents/skills/<category>/<name>/SKILL.md`.
- `data/agents/skills/local/` is still global-install; use it only when a dotfiles-specific skill should be available in every repo.
- Never edit installed copies in `~/.claude/skills/` or `~/.agents/skills/`; Home Manager regenerates them.
- Do not use `.claude/skills/` in this flake unless the skill must be Claude-only.

## Global agent config

- `data/agents/global/AGENTS.md` is the source for global instructions.
- `data/agents/global/settings.json` is the source for Claude settings.
- `data/agents/omp/` owns Oh-my-posh agent config.
- `modules/profiles/devenv/agents/global-config.nix` installs global config files.
- `modules/profiles/devenv/agents/skills.nix` installs global skills into each supported agent skill dir.

## Skill shape

```text
skills/<name>/
└── SKILL.md
```

or, for global-install skills:

```text
data/agents/skills/<category>/<name>/
└── SKILL.md
```

- Keep `SKILL.md` concise.
- Add sibling reference files only when they materially reduce the main skill.
- The frontmatter `description` must name specific triggers; it is what agents use for discovery.

## Decision rule

Ask: should this skill follow the user into unrelated repos?

- Yes: put it in `data/agents/skills/<category>/<name>/`.
- No: put it in root `skills/<name>/`.


## Global skill categories

- `engineering/`, `misc/`, `personal/`, `productivity/`: active global-install skills.
- `deprecated/`: kept for reference, not installed.
- `local/`: dotfiles-specific but still global-install.

## Upstream sync

- `flake skills-upstream`: review changed skills, then import or ignore new skills.
- `flake skills-upstream --apply-all`: copy upstream over local for every changed skill.
- `flake skills-upstream --apply-all --import-new`: also import every upstream-only skill.
- `.upstream-ignore` stores opted-out upstream skills.

## Checks

- For root `skills/`, verify the file exists and is not installed globally.
- For `data/agents/skills/`, build the affected Home Manager activation package and inspect both generated `.claude/skills` and `.agents/skills` when install behavior matters.
- Stage moved skill paths with `git add -A` so deletes and renames are tracked.
