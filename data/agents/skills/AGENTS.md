# AGENT SKILLS

## Purpose

Authored agent skills for global install. APM installs them from `local/`; see
`modules/profiles/devenv/agents/apm.nix`.

## Use skills

- `agent-structure` — project-only `.agents/skills/` vs global-install `data/agents/skills/`, installed copies, and agent config wiring.

## Local hazards

- APM names a skill after its **directory**, not the frontmatter `name`. Rename the directory to rename the skill.
- Add a new directory under `local/` and APM installs it on the next switch; no second declaration needed.
- Upstream skills are **not** vendored here. They are Claude Code plugins, declared in `data/agents/global/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`). APM deploys only the `local/` skills.
- A plugin comes whole; one skill cannot be excluded. The former `.upstream-ignore` opt-out no longer exists.
- Edit authored skills only under `local/`; project-only skills belong in `.agents/skills/`.
- Do not edit installed copies under `~/.claude/skills/`. APM overwrites them on switch.
- Refresh the local-skill lock with `apm update -g`, not `just update`. Plugins update on Claude Code start.
