# AGENT SKILLS

Skills and agent config are **managed in this flake** and installed into `$HOME` by Home Manager when `devenv.agents.enable = true`.

## Source of truth — edit in the flake only

**Always edit files under `data/agents/` in this repo.** Do not edit installed copies — they are overwritten or symlinked from the flake on `flake switch`.

| What | Edit here | Installed to (do not edit) |
|------|-----------|----------------------------|
| Skills | `data/agents/skills/<category>/<name>/` | `~/.claude/skills/`, `~/.agents/skills/` |
| Global agent instructions | `data/agents/global/AGENTS.md` | `~/AGENTS.md`, `~/.claude/CLAUDE.md`, … |
| Claude settings | `data/agents/global/settings.json` | `~/.claude/settings.json` |
| Oh-my-posh agent config | `data/agents/omp/` | `~/.omp/agent/` |

Wiring lives in `modules/profiles/devenv/agents/global-config.nix` (global files) and `modules/profiles/devenv/agents/skills.nix` (skill install). After edits, run `flake switch`.

## Structure

Nested categories mirroring the pinned `skills-mattpocock` input (`just skills-upstream`):
- `engineering/`, `misc/`, `personal/`, `productivity/` — active skills
- `deprecated/` — kept for reference, not installed
- `local/` — dotfiles-specific skills not in upstream

## Upstream Sync

```bash
flake skills-upstream                         # review changed skills, then import/ignore new skills
flake skills-upstream --apply-all             # copy upstream over local for every changed skill
flake skills-upstream --apply-all --import-new # also import every upstream-only skill
```

Skills to opt out of go in `.upstream-ignore` (one name per line, `#` comments).
