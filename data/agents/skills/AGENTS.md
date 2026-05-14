# AGENT SKILLS

Skills are hardcopied into the flake and install to `~/.agents/skills/` and `~/.claude/skills/` when `devenv.llm.agents.enable = true`.

## Structure

Nested categories mirroring `~/Git/skills/skills/`:
- `engineering/`, `misc/`, `personal/`, `productivity/` — active skills
- `deprecated/` — kept for reference, not installed
- `local/` — dotfiles-specific skills not in upstream

## Upstream Sync

```bash
just skills-upstream                         # review changed skills, then import/ignore new skills
just skills-upstream --apply-all             # copy upstream over local for every changed skill
just skills-upstream --apply-all --import-new # also import every upstream-only skill
```

Skills to opt out of go in `.upstream-ignore` (one name per line, `#` comments).
