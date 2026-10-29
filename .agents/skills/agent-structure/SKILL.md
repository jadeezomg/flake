---
name: agent-structure
description: Apply this flake's agent configuration layout rules. Use when editing agent skills, Claude Code mods (data/agents/mods), global agent instructions (AGENTS.md), Claude settings, OMP agent config, MCP server registration in apm.nix, agent CLI packages, or deciding between project .agents/skills and data/agents/skills/local.
---

# Agent Structure

## Scope

Use this skill for agent-facing files: `.agents/skills/`, `data/agents/**` (including `data/agents/mods/`), `modules/profiles/devenv/agents/`, and the installed copies in `$HOME`.

## Skill locations

- Project-only skills for this repo live in `.agents/skills/<name>/SKILL.md`.
- `.claude/skills` is a symlink to `../.agents/skills`. The `linkFlakeProjectSkills` activation step in `apm.nix` creates it on switch.
- Global-install skills that you author live in `data/agents/skills/local/<name>/`.
- Upstream global skills are Claude Code plugins. `data/agents/global/settings.json` names the marketplace under `extraKnownMarketplaces` and turns the plugin on under `enabledPlugins` (`ponytail@ponytail`, `simple-english@simple-english`). Claude Code installs them on start into `~/.claude/plugins`. They are not flake inputs and are not vendored in this repo.
- omp loads the Claude Code plugins too, through its `claude-plugins` source. omp treats the sources of other agents as opt-in, so `data/agents/omp/config.yml` lists it under `enabledProviders`. It loads the skills, slash commands, rules, tools, and MCP servers of each installed plugin. Of the plugin hooks, it runs only `hooks/pre/*.sh` and `hooks/post/*.sh`, not Claude's `hooks.json`. Checked with omp 18.13.2.
- omp loads an installed plugin unless `enabledPlugins` sets it to `false`. Claude Code loads it only when `enabledPlugins` sets it to `true`. So set each installed plugin that you do not use to `false`, or omp loads it.
- Repo-specific skill bundles, such as `mattpocock/skills`, are not global. Each repo that wants them declares them in its own project `apm.yml`. omp reads a project's `.claude/skills` by default (`skills.enableClaudeProject`), so APM's `claude` target there covers Claude Code and omp. Do not install such a bundle as a global plugin: omp would load it in every repo.
- omp does not see the claude.ai-synced plugins and skills (`~/.claude/plugins/synced/`, `~/.claude/skills/synced/`). They are not in `installed_plugins.json`.
- APM deploys the skills under `data/agents/skills/local/` into `~/.claude/skills` (Claude Code) and `~/.agents/skills` (pi, omp). omp skips `~/.claude/skills`, because `skills.enableClaudeUser` is off by default.
- For pi, APM also installs SimpleEnglish and, on work hosts, the caya plugins into `~/.agents/skills` only (target `agent-skills`).
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
- Yes, and it ships inside a Nix package: add its folder to `packageSkills` in `apm.nix` (for example the `terminal-browser` skill from `pkgs.llm-agents.terminal-browser`). APM deploys it like a local skill, and deploys it again when the package changes.
- Yes, and it is generic: enable its Claude plugin in `settings.json`. A plugin comes whole; one skill cannot be excluded.

## How APM is wired (`modules/profiles/devenv/agents/apm.nix`)

- The module renders the manifest and writes it to `~/.apm/apm.yml` as a read-only store symlink.
- `targets = [ "claude" "agent-skills" ]`. `claude` writes the skills to `~/.claude/skills` and the MCP servers to Claude's config, which Zed's Claude ACP agent also reads. `agent-skills` writes the skills to `~/.agents/skills` for pi and omp.
- omp reads MCP servers from its own `~/.omp/agent/mcp.json`. APM does not write that file, so a server change in `apm.nix` does not reach omp. Edit that file by hand on each host.
- The `apmInstall` activation step runs `apm update -g --yes` after `linkGeneration`. Before that step, `~/.apm/apm.yml` still links to the previous generation's manifest. It is non-fatal. An offline switch leaves installed skills stale; the next switch retries.
- Before the update, `fixLocalCopyPerms` runs `chmod -R u+rwX` on `~/.apm/apm_modules/_local` and on each local skill in `~/.claude/skills` and `~/.agents/skills`. APM copies the store-path skills with their read-only mode. Its `rmtree` fallback then sets mode 0200 (write-only), and every later install fails with "Permission denied". The step carries a `recheckWhen` guard on the apm version. If `~/.claude/skills` is missing while `~/.apm/apm_modules` is populated, this is the first thing to check.
- If APM fails part way, it can deploy files but not write `~/.apm/apm.lock.yaml`. The next run then refuses them: "conflicts with unmanaged file". To repair, compare each deployed skill folder with the lock. Move the unrecorded folders that are unchanged copies of the store source to the trash, then switch again.
- Ad-hoc `apm install <pkg>` fails by design. Add new packages to `manifest` in `apm.nix` instead.
- Each switch updates both: `apmInstall` runs `apm update -g`, and `claudePluginsUpdate` updates the marketplaces and plugins. The switch steps that run `claude` pass a settings file with `disableAllHooks`, so the session hooks of `settings.json` do not fire. `just update` does not touch either. It runs `update-packages`, `nix flake update`, `just fmt`, and optional `fwupdmgr`.

## Claude Code mods

A mod is a Claude Code plugin of function hooks: a pane, a command, or a hook on tool calls.

- Mods live in `data/agents/mods/<name>/`. Each has `.claude-plugin/plugin.json`, `hooks/hooks.json`, and the hooks module.
- `settings.json` loads them through `env.CLAUDE_CODE_PLUGIN_DIRS`. The value is a `:`-separated list of folders. Claude Code expands `~`, so one value works on every host.
- To add a mod, append its folder to that value. To turn a mod off, remove its folder.
- A saved edit reloads the mod in every open interactive session. No switch is needed. A change to `settings.json` takes effect in the next session.
- When Claude Code loads a mod, it writes `.claude-plugin/types/`. That folder holds its own `.gitignore`. Do not edit it. Keep the top-level `tsconfig.json`, which extends it.
- Before you commit a change, run `claude plugin validate <dir>` and `claude plugin test <dir>`. Type-check with `tsc -p <dir>` after Claude Code loaded the mod once.
- Mods load in Claude Code only. omp, pi, and Zed do not read them.
- The Caya account is on a Team plan, so Claude Code seats its built-in guard `cc-plugin-sec-default` ahead of every mod here. The guard skips a mod's `session.compact` hooks: Claude Code always makes its own summary. It also keeps injected rows (reminders, hook context, compaction rows) from `session.append` rewrites. `claude plugin test` runs without the guard. To make sure that a hook runs, use `claude --plugin-dir <dir> --debug-file <log> -p ...` and search the log for `bypassed`.

## MCP servers

- MCP registration also lives in `manifest.dependencies.mcp` in `apm.nix`.
- Use `mkHttpServer name url` for remote servers and `mkStdioServer name` for local binaries. Both set `registry = false`.
- When you remove a server from `manifest.dependencies.mcp`, APM drops it from its lock but keeps it in `~/.claude.json` (seen 2026-10-29 with apm 0.35.0). Remove it on each host with `claude mcp remove <name> -s user`.
- APM does not take over an entry that it did not create ("conflicts with the existing claude connection"). So `apmInstall` first removes each `~/.claude.json` entry that has the name of a declared server but is not in the `mcp_servers` list of APM's lock. APM then adds its own copy in the same run.
- Current servers: `context7-mcp` (stdio), `mcp-nixos` (stdio, not on Darwin), `linear` (http, only when `dotfiles.profiles.work.enable` is true).
- A stdio server needs its binary in `environment.systemPackages` in `default.nix` (`context7-mcp`, `mcp-nixos`). Keep both gates in sync; `default.nix` also skips `mcp-nixos` on Darwin.
- Remote servers authenticate interactively per client. There is no secret to wire.

## Global agent config

- `data/agents/global/AGENTS.md` is the source for global instructions.
- `data/agents/global/settings.json` is the source for Claude settings.
- `data/agents/global/themes/dark-ansi-dock.json` is the custom Claude theme that `settings.json` selects. It is `dark-ansi` with the docked pane on the terminal background.
- `data/agents/omp/config.yml` and `data/agents/omp/themes/birds-of-paradise.json` own the Oh-my-posh agent config.
- `global-config.nix` installs these as live symlinks (`mkOutOfStoreSymlink` and `mkLiveSymlink`). Edits take effect without a rebuild.
- `AGENTS.md` fans out to `~/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.config/agents/AGENTS.md`, and `~/.pi/agent/AGENTS.md`. Claude Code reads `~/AGENTS.md` as a parent of every project under `$HOME`, so there is no `~/.claude/CLAUDE.md`. Sessions outside `$HOME` get no global instructions.
- Do not edit the installed copies. Edit the source under `data/agents/` instead.

## Path helpers (`lib/default.nix`)

- `agentsDataDir`: `../data/agents` as a store path.
- `agentSkillsDir`: `../data/agents/skills` as a store path. `apm.nix` builds its `path:` deps from it on purpose, so APM does not depend on where the flake is checked out.
- `agentDataFiles flakeRoot`: live checkout paths. Keys: `root`, `globalAgentsMd`, `claudeSettings`, `claudeTheme`, `ompConfig`, `ompTheme`, `localSkills`.
- `agentSessionSources`: `data/agents/session-sources.nix` as Nix data. It lists where each agent keeps its sessions. The session push and the archive on mini read it.
- Add new agent data files to `agentDataFiles`, or to `dotfilesLib` when modules import them as Nix. Do not hardcode `data/agents/...` in modules.

## Sibling modules (`modules/profiles/devenv/agents/`)

- `default.nix`: registers the HM modules below in `home-manager.sharedModules` and installs agent CLI packages in `environment.systemPackages`. Most come from `pkgs.llm-agents`. A new agent CLI goes here.
- `agent-review.nix` and `agent-review.bash`: the `agent-review` command. It starts an omp reviewer in a new herdr pane for the change of the agent in the current pane. The agents send messages to each other with `herdr agent prompt`. The local skills `request-review` (author) and `peer-review` (reviewer) hold the protocol. State is in `<git dir>/agent-review/<review>/`.
- `apm.nix`: skills and MCP (above).
- `global-config.nix`: live symlinks for global config (above).
- `retired-cleanup.nix`: one-time steps that remove what a retired tool left on each host (opencode state folders, the openwork MCP entries, the global mattpocock-skills plugin). Each step does nothing once its target is gone. Delete a step after every host has switched once.
- `herdr-plugins.nix`: links herdr plugin folders from flake packages (`share/herdr/plugins/<id>`) with `herdr plugin link` on switch. It unlinks a store-path plugin that left the list. herdr writes its registry (`~/.config/herdr/plugins.json`) itself, so the flake cannot own that file. Hand-linked and `herdr plugin install` plugins stay as they are.
- `nono-agent.nix` and `nono-profiles.nix`: nono dispatcher and profiles. Profile data lives in `lib/nono-profiles.nix`.
- `pi-packages.nix`: declarative pi packages in `~/.pi/agent/settings.json`.
- `session-push.nix`: a systemd user timer that pushes the session folders from `agentSessionSources` to the archive on mini (`hosts/mini/services/agent-sessions.nix`). Linux only. It runs only when the host has `agentPushKey` in its `host.nix`.
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
