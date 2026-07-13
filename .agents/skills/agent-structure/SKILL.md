---
name: agent-structure
description: Apply this flake's agent configuration layout rules. Use when editing agent skills, global agent instructions, Claude settings, OMP agent config, or deciding between project .agents/skills and data/agents/skills.
---

# Agent Structure

## Scope

Use this for agent-facing files: `.agents/skills/`, `data/agents/**`, installed agent dirs, and agent config wiring.

## Skill locations

- Project-only skills for this repo live in `.agents/skills/<name>/SKILL.md`.
- `.claude/skills` symlinks to `.agents/skills` in the flake root (Claude reads the same tree).
- Global-install skills live in `data/agents/skills/local/` (overrides) plus the pinned `skills-mattpocock` input (upstream).
- `data/agents/skills/local/` is still global-install; use it only when a dotfiles-specific skill should be available in every repo.
- Never edit installed copies in `~/.agents/skills/`; `~/.claude/skills` symlinks there. Home Manager regenerates them.

## Global agent config

- `data/agents/global/AGENTS.md` is the source for global instructions.
- `data/agents/global/settings.json` is the source for Claude settings.
- `data/agents/omp/` owns Oh-my-posh agent config.
- `modules/profiles/devenv/agents/global-config.nix` installs global config files.
- `modules/profiles/devenv/agents/skills.nix` installs global skills under `~/.agents/skills`, symlinks `~/.claude/skills` there, and maintains repo `.claude/skills` → `.agents/skills`.

## Skill shape

```text
.agents/skills/<name>/
└── SKILL.md
```

or, for global-install local overrides:

```text
data/agents/skills/local/<name>/
└── SKILL.md
```

- Keep `SKILL.md` concise.
- Add sibling reference files only when they materially reduce the main skill.
- The frontmatter `description` must name specific triggers; it is what agents use for discovery.

## Decision rule

Ask: should this skill follow the user into unrelated repos?

- Yes (dotfiles-specific override): put it in `data/agents/skills/local/<name>/`.
- Yes (generic, upstream-owned): rely on `skills-mattpocock`; opt out via `.upstream-ignore` if needed.
- No: put it in `.agents/skills/<name>/`.


## Global skill categories

- `local/`: dotfiles-specific overrides (still global-install; wins over upstream on name clash).
- Upstream categories (`engineering/`, `productivity/`, …) live in the flake input only.

## Upstream skills

- Upstream skills come from the pinned `skills-mattpocock` flake input — installed automatically on switch.
- Local overrides live in `data/agents/skills/local/` (same skill name wins).
- Opt-outs: `data/agents/skills/.upstream-ignore`.
- `just update`: refreshes the upstream pin via `flake.lock`.

## Checks

- For `.agents/skills/`, verify the file exists and is not installed globally.
- For `data/agents/skills/local/`, build the affected Home Manager activation package and inspect generated skill dirs when install behavior matters.
- Stage moved skill paths with `git add -A` so deletes and renames are tracked.
