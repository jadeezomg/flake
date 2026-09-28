---
name: agent-structure
description: Apply this flake's agent configuration layout rules. Use when editing agent skills, global agent instructions (AGENTS.md), Claude settings, OMP agent config, MCP server registration in apm.nix, agent CLI packages, or deciding between project .agents/skills and data/agents/skills/local.
---

# Agent Structure

## Scope

Use this skill for agent-facing files: `.agents/skills/`, `data/agents/**`, `modules/profiles/devenv/agents/`, and the installed copies in `$HOME`.

## Skill locations

- Project-only skills for this repo live in `.agents/skills/<name>/SKILL.md`.
- `.claude/skills` is a symlink to `../.agents/skills`. The `linkFlakeProjectSkills` activation step in `apm.nix` creates it on switch.
- Global-install skills that you author live in `data/agents/skills/local/<name>/`.
- Upstream global skills are Claude Code plugins. `data/agents/global/settings.json` names the marketplace under `extraKnownMarketplaces` and turns the plugin on under `enabledPlugins` (`mattpocock-skills@mattpocock`, `ponytail@ponytail`, `simple-english@simple-english`). Claude Code installs them on start into `~/.claude/plugins`. They are not flake inputs and are not vendored in this repo.
- Plugins are visible to Claude Code only. APM deploys only the two local skills into `~/.claude/skills`, which omp and Zed's ACP agents also read.
- Never edit installed copies under `~/.claude/skills/`. APM overwrites them on switch.

## Skill shape

```text
.agents/skills/<name>/           # project-only
└── SKILL.md

data/agents/skills/local/<name>/ # global-install, authored here
├── SKILL.md
└── references/                  # optional, see dotfiles-tools
```

- Keep `SKILL.md` concise.
- Add a `references/` dir only when it makes `SKILL.md` much shorter.
- The frontmatter `description` must name specific triggers. Agents use it for discovery.
- APM names a global skill after its directory, not after the frontmatter `name`. Rename the directory to rename the skill.

## Decision rule

Ask: must this skill follow the user into unrelated repos?

- No: put it in `.agents/skills/<name>/`.
- Yes, and it is dotfiles-specific: put it in `data/agents/skills/local/<name>/`. A new directory is enough. `apm.nix` derives `localSkills` from `readDir` of that folder, so there is no list to update.
- Yes, and it is generic: enable its Claude plugin in `settings.json`. A plugin comes whole; one skill cannot be excluded.

## How APM is wired (`modules/profiles/devenv/agents/apm.nix`)

- The module renders the manifest and writes it to `~/.apm/apm.yml` as a read-only store symlink.
- `targets = [ "claude" ]`. omp and Zed's ACP agents read Claude's config, so this one target covers them.
- The `apmInstall` activation step runs `apm install -g`. It is non-fatal. An offline switch leaves installed skills stale; the next switch retries.
- Before the install, `fixLocalCopyPerms` runs `chmod -R u+rwX ~/.apm/apm_modules/_local`. APM copies the store-path skills with their read-only mode, and its `rmtree` fallback then sets mode 0200 (write-only), which makes every later install fail with "Permission denied" before it deploys anything. The step carries a `recheckWhen` guard on the apm version. If `~/.claude/skills` is missing while `~/.apm/apm_modules` is populated, this is the first thing to check.
- Ad-hoc `apm install <pkg>` fails by design. Add new packages to `manifest` in `apm.nix` instead.
- Plugins update themselves on Claude Code start. Refresh the local-skill lock with `apm update -g`. `just update` does not touch either. It runs `update-packages`, `nix flake update`, `just fmt`, and optional `fwupdmgr`.

## MCP servers

- MCP registration also lives in `manifest.dependencies.mcp` in `apm.nix`.
- Use `mkHttpServer name url` for remote servers and `mkStdioServer name` for local binaries. Both set `registry = false`.
- Current servers: `openwork` (http), `context7-mcp` (stdio), `mcp-nixos` (stdio, not on Darwin), `linear` (http, only when `dotfiles.profiles.work.enable` is true).
- A stdio server needs its binary in `environment.systemPackages` in `default.nix` (`context7-mcp`, `mcp-nixos`). Keep both gates in sync; `default.nix` also skips `mcp-nixos` on Darwin.
- Remote servers authenticate interactively per client. There is no secret to wire.

## Global agent config

- `data/agents/global/AGENTS.md` is the source for global instructions.
- `data/agents/global/settings.json` is the source for Claude settings.
- `data/agents/omp/config.yml` and `data/agents/omp/themes/birds-of-paradise.json` own the Oh-my-posh agent config.
- `global-config.nix` installs these as live symlinks (`mkOutOfStoreSymlink` and `mkLiveSymlink`). Edits take effect without a rebuild.
- `AGENTS.md` fans out to `~/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.config/agents/AGENTS.md`, and `~/.pi/agent/AGENTS.md`.
- Do not edit the installed copies. Edit the source under `data/agents/` instead.

## Path helpers (`lib/default.nix`)

- `agentsDataDir`: `../data/agents` as a store path.
- `agentSkillsDir`: `../data/agents/skills` as a store path. `apm.nix` builds its `path:` deps from it on purpose, so APM does not depend on where the flake is checked out.
- `agentDataFiles flakeRoot`: live checkout paths. Keys: `root`, `globalAgentsMd`, `claudeSettings`, `ompConfig`, `ompTheme`, `localSkills`.
- Add new agent data files to `agentDataFiles`. Do not hardcode `data/agents/...` in modules.

## Sibling modules (`modules/profiles/devenv/agents/`)

- `default.nix`: registers the HM modules below in `home-manager.sharedModules` and installs agent CLI packages in `environment.systemPackages`. Most come from `pkgs.llm-agents`. A new agent CLI goes here.
- `apm.nix`: skills and MCP (above).
- `global-config.nix`: live symlinks for global config (above).
- `nono-agent.nix` and `nono-profiles.nix`: nono dispatcher and profiles. Profile data lives in `lib/nono-profiles.nix`.
- `pi-packages.nix`: declarative pi packages in `~/.pi/agent/settings.json`.
- `tuicr.nix`: the `git review` alias for tuicr.

## Related files

- `.claude/settings.local.json` is git-ignored, machine-local permissions. Do not copy it into the flake by hand.
- `lib/host-status.nix` `skills_status` counts the directories under `data/agents/skills/local`.
- Keep the nested docs in sync: `.agents/skills/AGENTS.md` and `data/agents/skills/AGENTS.md`.

## Checks

- Do not build or switch yourself. Ask the user to run `just switch` and report back.
- For `data/agents/skills/local/`, inspect the rendered manifest: `cat ~/.apm/apm.yml`. Every `local/` directory must appear as a `path:` dep.
- For `.agents/skills/`, confirm the `SKILL.md` exists and is not also under `data/agents/skills/local/`.
- Stage moved skill paths with `git add -A`. Flakes only see tracked files.
