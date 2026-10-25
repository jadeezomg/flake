# Plan: Agent session management across hosts

**Status:** decided 2026-10-25, Phase 0 next
**Related:** [mini.md](../hosts/mini.md), [ADR-0001](../adr/0001-nono-as-single-sandboxing-system.md), [hermes.nix](../../hosts/mini/services/hermes.nix), [atuin.nix](../../hosts/mini/services/atuin.nix), [immich-backup.nix](../../hosts/mini/services/immich-backup.nix), [`modules/profiles/devenv/agents/`](../../modules/profiles/devenv/agents/)

---

## Summary

mini becomes the one place where you find every terminal agent session. The plan has two parts:

- **History (C, required).** Every host sends its agent session files to mini. mini indexes them, makes them searchable, and backs them up.
- **Run location (A, B, or H, per session).** When you start a session, you pick where its agent runs: on mini (A), or on the laptop with a live view from other hosts (B). Hermes on mini is a third run location (H).

Status events and telemetry (D) are out of scope. This plan describes D so that the design leaves room for it.

## Terms

| Term | Meaning |
|---|---|
| Session | One conversation of one agent, with its transcript file or database rows. |
| Run host | The host where the agent process runs. |
| Session manager | The multiplexer that keeps agent processes alive when no client is attached (herdr, tmux, and others). |
| Archive | The copy of all session files on mini. |
| Client | A terminal that attaches to a session manager: a laptop or a phone. |

---

## Current state (2026-10-25)

| Item | State |
|---|---|
| herdr | 0.9.5 on every `devenv` host, mini included. The Claude `SessionStart` hook is in `data/agents/global/settings.json`, so every host has it. mini has no integrations installed. No host has saved machines. |
| tmux, sesh | On every host (`modules/profiles/minimal/shells/core/tmux.nix`). |
| mini capacity | `free -g` shows 31 GB total, 22 GB available. `docs/hosts/mini.md` says 24 GB. `/srv` has 1.6 TB free. `buildCores = 2`. |
| mini user | `Linger=yes` for jadee (set by `modules/nixos/virtualization.nix` for `devenv` hosts). |
| mini content | No repos. No `~/.claude/projects`. `~/.pi`, `~/.omp`, `~/.codex` exist. The flake checkout was at `~/.dotfiles/flake` (moves to `~/git/flake`, D9). |
| Repo folders | framework keeps repos in `~/Git` (capital G, 6 entries). `~/Projects` is empty. `modules/profiles/desktop/noctalia/config/settings.toml` points at `~/Git/community-plugins`. desktop not checked. |
| hermes | System service, user `hermes`, `HERMES_HOME=/var/lib/hermes/.hermes`. Matrix and Telegram gateway. Dashboard at `hermes.jadee.fyi`. Model access through OpenRouter. |
| Network | mini firewall trusts `tailscale0` only. Laptops accept Tailscale SSH only. framework → mini SSH works in `BatchMode` over the LAN address. |
| caya | `sshAddress = null`. Nothing connects into caya. Work laptop. |
| Claude Remote Control | `remoteControlAtStartup = true`. Claude sessions already show on claude.ai/code. |
| Precedents on mini | atuin collects shell history from all hosts. restic over SFTP backs up Immich to Unraid. |

---

## Goals

1. One archive on mini holds the sessions of desktop, framework, mini, and hermes. caya is out of scope (D1).
2. You can search the archive from any host over SSH. The archive has an off-host backup.
3. One command starts a session in the run mode that you pick: `local`, `mini`, or `hermes`.
4. From any client, laptop or phone, you can attach to agents that run on mini.
5. You can turn on a live view of local agents from other hosts.

## Non-goals

- D: status events, push notifications, OpenTelemetry. See [§ D](#d-status-events-and-telemetry-out-of-scope).
- A web terminal or session UI outside the tailnet.
- Resume of a laptop session on a different host. Claude keys sessions by project path, so this is a separate problem.
- Work (caya) sessions and work code on mini (D1).

---

## Decisions (Phase 0)

| # | Question | Options | Recommendation |
|---|---|---|---|
| D1 | Do caya sessions go to the archive? | (a) No. (b) Yes, in a separate restic repo with its own key. (c) Yes, same as personal hosts. | **Decided 2026-10-25: (a).** Work sessions are out of scope. The push design works for caya later, because caya connects out. |
| D2 | Which session manager? | herdr, tuios, or another tool from [§ Session manager](#session-manager). | **Decided 2026-10-25: trial both** on mini. herdr is the default until the trial ends. |
| D3 | Where does a project declare its run mode? | (1) Registry in the flake. (2) Marker file in each repo. (3) Flag at start only. | **Decided 2026-10-25: (3).** See [§ Mode selection](#mode-selection). |
| D4 | How do session files reach mini? | rsync push timer, Syncthing, or the index tool's own sync. | **Decided 2026-10-25:** rsync push timer with a write-only key. See [§ Transport](#transport). |
| D4b | Which SSH path for the push off the LAN? | Second OpenSSH port on `tailscale0`, LAN only, or Tailscale SSH without a forced command. | **Decided 2026-10-25:** port 2222 on the tailnet only, dedicated user `agent-push`. See [§ Push path](#push-path-d4b). |
| D5 | Which index and search tool? | agentsview, cass, and others. | **Decided 2026-10-25:** agentsview. See [§ Index and search](#index-and-search). |
| D6 | Which user runs the coding agents that hermes starts? | (H1) User `hermes`. (H2) User `jadee`. | **Decided 2026-10-25:** H1, user `hermes`. |
| D7 | How do hosts connect to each other without a prompt (mode B)? | Tailscale SSH policy `accept` for these host pairs, OpenSSH with keys on the laptops, or no mode B for now. | **Decided 2026-10-25:** Tailscale SSH `accept` rules for the host pairs. The ACL lives in the Tailscale admin console. Test in Phase 0. |
| D8 | Can agents on mini edit the flake checkout on mini? | Yes, with a rule change in `AGENTS.md`. No, flake work stays `local`. | **Decided 2026-10-25: yes.** See [§ Flake work on mini](#flake-work-on-mini-d8). |
| D9 | Where do git repos live? | Flat `~/git/<repo>`, or `~/git/<owner>/<repo>`. Flake inside or outside `~/git`. | **Decided 2026-10-25:** flat `$HOME/git/<repo>` for every user on every host. Changed 2026-10-26: the flake checkout moves too, to `~/git/flake`. See [§ Repo location](#repo-location-d9). |
| D10 | How does the push leave out work repos on personal hosts? | Exclude list, exclude by `origin` owner, no work repos on personal hosts, or filter in agentsview. | **Decided 2026-10-25: manual.** You manage these sessions by hand. The push has no filter. See [§ Work repos on personal hosts](#work-repos-on-personal-hosts). |

---

## Run modes

You pick the mode when you start a session (D3). Without a flag, the mode is `local`.

This section uses herdr as the session manager. If D2 picks tuios, the same steps apply with the tuios commands (`tuios hosts add` in place of `herdr machine add`).

### Mode `local` (B)

The agent runs on the laptop in a local herdr session. Other hosts can see it live.

- Each laptop runs its own herdr server.
- `herdr machine add <host>` saves the other hosts as machines. The sidebar then shows their workspaces and agent states.
- Variant "mini shows all": on mini, add desktop and framework as machines. From the phone, SSH to mini and run `herdr`. You then see every host.
- A sleeping laptop drops out. herdr shows its last state as dimmed cache.
- caya can only be a client. Its own agents stay invisible to other hosts.

Needs: SSH without a prompt between the hosts that view each other (D7).

### Mode `mini` (A)

The agent runs on mini in mini's herdr session. You attach from any client.

- A systemd user service on mini runs `herdr server`. Linger is already on.
- Each laptop saves mini once: `herdr machine add mini`. The phone uses an SSH app and runs `herdr` on mini.
- Sessions keep running when a laptop sleeps or changes network.
- After a mini reboot, the layout returns. Claude conversations return through herdr's native session restore. Other processes start again as new shells.

Needs on mini:

- Repo clones, made on demand by `work --on mini`.
- Git identity and a GitHub token for the agent identities.
- One interactive login per agent (Claude, codex, pi provider keys).
- herdr integrations for claude, pi, omp, codex, and opencode.
- A memory limit for the herdr service, so that agent builds do not starve llama.cpp.

Limits: no GUI, no browser on screen, and only 2 build cores for Nix builds.

### Mode `hermes` (H)

You give a task to hermes in Matrix, Telegram, or the dashboard. Hermes runs the coding agent on mini.

- Hermes has bundled skills for Claude Code and Codex. It uses print mode (`claude -p`) for one-shot tasks and a tmux session for multi-turn tasks ([skill](https://github.com/NousResearch/hermes-agent/blob/main/skills/autonomous-ai-agents/claude-code/SKILL.md)).
- The agent runs as user `hermes` with `HOME=/var/lib/hermes` (D6, H1). It needs its own Claude login or API key, and its own checkouts or worktrees.
- `GITHUB_TOKEN` is already in `hermes.env` (`agent_pat`).
- You see the hermes conversation in its dashboard. The tmux session of the coding agent belongs to user `hermes`. You attach with `sudo -u hermes tmux attach`, not through your herdr.
- herdr has a hermes integration. It reports state only when hermes runs inside a herdr pane. The gateway service does not run in a pane.

### Comparison

| | `local` (B) | `mini` (A) | `hermes` (H) |
|---|---|---|---|
| Agent runs on | Laptop | mini | mini, as user `hermes` |
| Survives laptop sleep | No | Yes | Yes |
| Phone access | Only through mini's view (variant) | Yes, SSH + `herdr` | Yes, Matrix or Telegram |
| Live view from other hosts | herdr saved machines | herdr saved machines | Hermes dashboard |
| GUI, browser, local hardware | Yes | No | No |
| Credentials | Already on the laptop | Copy to mini | Separate set for `hermes` |
| Good for | Interactive work, GUI and browser tasks | Long tasks, overnight runs, personal repos | Small tasks you start from the phone |

---

## Mode selection

Decided (D3): you pick the mode with a flag when you start. The flake keeps no list of projects and their modes.

Options that were not picked:

- A registry in the flake (`data/agents/projects.nix`) with one mode per project.
- A marker file in each repo, such as `.agents/run-host`.

### The `work` command (sketch)

`work [<path>] [--on local|mini|hermes]`. The path defaults to the current folder. The mode defaults to `local`.

| Mode | Action |
|---|---|
| `local` | Open or attach the local herdr workspace for the path. |
| `mini` | The path must be `~/git/<repo>` or the flake checkout. If mini has no `~/git/<repo>`, clone it there from the local `origin` URL. Then attach to mini (`herdr --remote mini`, or the saved machine) and open the workspace there. |
| `hermes` | Print the hermes dashboard URL and the Matrix room. |

Notes:

- If the path is outside `~/git/` and is not the flake checkout, `work --on mini` stops with an error. Move the repo into `~/git/` first.
- Because every host uses `~/git/<repo>` (D9), the path is the same on the laptop and on mini. Claude, pi, and omp name their session folders after the path, so the archive groups sessions of one repo from both hosts under the same name.
- Do not copy uncommitted work. If the local tree is dirty, `work --on mini` prints a warning and continues with the clone on mini.
- Before you write the command, read the herdr [CLI reference](https://herdr.dev/docs/cli-reference/) for the workspace flags. This plan does not assume any flag that this document does not show.

### Repo location (D9)

Decided: every git repo lives at `$HOME/git/<repo>`.

- The layout is flat. `<repo>` is the folder name. By default it is the repo name from the `origin` URL, without `.git`.
- If two repos have the same name, pick a different folder name by hand at clone time. `work --on mini` then uses the same folder name on mini.
- The rule applies to every user on every host: jadee on desktop, framework, and mini, and user `hermes` (`/var/lib/hermes/git/`).
- There is no exception. Since 2026-10-26 the flake checkout lives at `~/git/flake` on every host (it was at `~/.dotfiles/flake`). `dotfiles.flakeRoot` defaults to that path. The move steps are in [§ Moving the flake checkout](#moving-the-flake-checkout).
- A Home Manager module creates `~/git` on each host, so that the folder exists before the first clone.

Migration on framework (contents on 2026-10-25):

| Entry in `~/Git` | Kind | Action |
|---|---|---|
| `community-plugins` | Repo, `jadeezomg` | Moves with the folder. Update the path in `modules/profiles/desktop/noctalia/config/settings.toml`. |
| `dotfiles` | Repo, `Mic92/dotfiles` (reference copy) | Moves with the folder. |
| `graphs` | Repo, `AMN-DATA` (work) | Moves with the folder. Its sessions are work sessions, see the note below. |
| `skills` | Repo, `mattpocock/skills` | Moves with the folder. |
| `learn-rust` | Folder with 3 repos inside | Keep as a group folder, or move the 3 repos to the top level. Your choice. |
| `vault` | Not a repo | Keep, or move out of `~/git`. Your choice. |

Steps: run `mv ~/Git ~/git` on framework, then update the noctalia path. On a case-sensitive file system, this is one rename. That noctalia file has uncommitted local changes today, so make the path change together with those changes. Do the same check on desktop.

Note on work repos on personal hosts: `graphs` is a work repo on framework. D1 removes caya. The push still sends the sessions of `~/git/graphs` on framework to the archive. You manage them by hand (D10). See [§ Work repos on personal hosts](#work-repos-on-personal-hosts).

### Moving the flake checkout

`dotfiles.flakeRoot` now defaults to `~/git/flake`. Live symlinks, `$FLAKE`, `$NH_FLAKE`, the flake git hooks, and the sesh `flake` session follow it after a switch. Do these steps on each host, mini first, because the new `just mini deploy` recipes expect `~/git/flake` on mini.

1. In the old checkout, run `git pull`.
2. Move the checkout and leave a symlink at the old path: `mv ~/.dotfiles/flake ~/git/flake && ln -s ../git/flake ~/.dotfiles/flake`.
3. Switch from the new path: `cd ~/git/flake && just switch`.
4. Open a new shell. Make sure that `echo $FLAKE` shows the new path.
5. When nothing uses the old path, remove the symlink: `trash ~/.dotfiles/flake`.

The symlink keeps open shells, running agent sessions, and the old live symlinks working until the switch. Claude Code names its project folder after the path. Copy the auto memory from `~/.claude/projects/-home-jadee--dotfiles-flake/memory/` to `~/.claude/projects/-home-jadee-git-flake/memory/`.

### Flake work on mini (D8)

Decided: agents that run on mini can edit mini's flake checkout. mini has a clean clone of `jadeezomg/dotfiles` on `main` at `~/.dotfiles/flake` (moves to `~/git/flake`, D9), with `.flake-host = mini`.

The two rules today:

- `AGENTS.md` (flake): "Never edit configs over SSH on remotes (`mini`, etc.) — remotes are for inspect/deploy/ops only."
- `data/agents/global/AGENTS.md`: "Always edit config/source on the host you are running on (the local checkout). Never change configs over SSH on remote hosts."

An agent that runs on mini and edits mini's own checkout already obeys the global rule, because mini is the host it runs on. The flake rule names mini as a remote, so it needs new text. Proposed text for the flake `AGENTS.md`:

> Edit flake config only in the checkout of the host the agent runs on. An agent that runs on mini edits mini's checkout. Never edit a checkout over SSH from another host. The user reviews the diff on the host where the agent made it.

What does not change:

- Agents still never run `just build*`, `just switch`, or any other system build.
- `.flake-host` stays untouched.

New risk: two checkouts (desktop and mini) can diverge. Commit and push from mini when a session ends. Pull before you start a session on the other host.

---

## Session manager

The session manager keeps agent processes alive and shows their state. Modes A and B depend on it. Mode H does not, because hermes uses its own tmux.

Checked on 2026-10-25.

| Tool | Detach / restart | Remote and multi-machine | Agent state | Phone | Worktrees | Nix | Maturity |
|---|---|---|---|---|---|---|---|
| **herdr** (installed) | Server. After restart: layout, plus native resume for Claude. | `--remote`, `machine add`: several hosts in one sidebar | working, blocked, done. Integrations for claude, pi, omp, codex, opencode, hermes. | SSH TUI. Collie PWA (in `llm-agents`). | Yes | `llm-agents.herdr` 0.9.5 | Apache-2.0. Pre-1.0. |
| **tuios** | Daemon. After restart: layout, cwd, scrollback. The Inbox offers to resume agent conversations. | `tuios hosts add` over SSH, `tuios hosts tailnet` discovery. Sidebar per machine. One Inbox for all hosts. Starts agents on other hosts (`fan --host`). | working, needs input, idle, done. Hooks for claude, codex, opencode, pi, omp. hermes by hook and screen. | `tuios-web` in a browser. Android app in private beta. | `tuios worktree`, `tuios fan` | nixpkgs 0.10.1 has advisory GHSA-78rj-pghh-vh42 (one pane can answer another pane's prompt). Fixed in 0.11.0. Upstream flake. | MIT. v0.11.0 on 2026-10-25. Pre-1.0, many changes each week. |
| agent-deck | tmux. Resume per agent. | `[remotes.*]` over SSH. Remote rows in the TUI. | running, waiting, idle, error. claude, codex, opencode, pi, omp, hermes. | `agent-deck web`. Telegram and Slack bridge. | Yes | `llm-agents.agent-deck` | MIT. Active. |
| agent-of-empires | tmux plus `aoe serve`. Native resume for claude, codex, pi, omp, hermes. | SSH, `aoe serve --remote`. One host per daemon. | Yes, same agents | Web dashboard, mobile view, PWA, push | Yes, also containers | Own flake only | MIT. Active. |
| zellij | Server. Resurrects layout; commands wait for your confirmation. | SSH, HTTPS attach. No multi-host view. | None | Web client, mobile UI, PWA | No | nixpkgs 0.45.1 | MIT. Mature. |
| tmux + sesh (installed) | Server. Restart only with tmux-resurrect. | SSH. No multi-host view. | None | SSH app | No | nixpkgs | Very mature. |
| workmux | Uses tmux, zellij, kitty, or wezterm. | Through the backend. No multi-host view. | working, waiting, done | SSH | Core feature | `llm-agents.workmux` | MIT. Active. |
| happy | Daemon per machine, E2E relay (self-hostable) | The app lists sessions from several machines. | In the app | Native iOS and Android, web | Not verified | `llm-agents.happy-coder` | Claude Code and Codex only. Focus moved to a desktop app. |
| shpool, zmx | Daemon. No restart restore. | SSH. No multi-host view. | None | SSH | No | nixpkgs | Small tools, no agent features. |

Dropped: ccmanager and claude-squad (no remote, no pi or omp), dmux (no remote), omnara (now a hosted agent platform), vibe-kanban (shut down), abduco and dtach (inactive or too small), wezterm mux (no release since 2024), cmux and Conductor (macOS GUI only).

### Fit per mode

- **A (`mini`):** herdr, tuios, agent-deck, and agent-of-empires all work. tuios and agent-of-empires have the best phone story (web client). zellij works too, but does not track agent state.
- **B (`local` with live view):** only herdr, tuios, and agent-deck show agents from several hosts in one UI. tuios is the strongest: one Inbox for every host, and you can answer prompts from it. agent-deck cannot send messages to remote rows.

### Recommendation (D2)

Pick between herdr and tuios with a trial. Do not pick by the feature table alone, because both are pre-1.0 and change each week.

- **herdr** is installed and its Claude hook is in `settings.json`. Lowest cost to start.
- **tuios** matches B and the phone better: tailnet discovery, a cross-host Inbox, agents started on other hosts, and a web client.
- For the trial, run both on mini for one `mini` project for one week. Compare: reconnects after laptop sleep, phone use, Claude resume after a daemon restart, and memory use.
- If tuios wins, take it from its upstream flake or bump it with an overlay that has an expiry guard. Do not use nixpkgs 0.10.1.

Both tools install hooks into the agent config files. tuios writes through a symlinked `settings.json` on purpose. On our hosts, that file is a live symlink into the flake checkout, so an install changes the repo. Put the hook entries into `data/agents/global/settings.json` by hand, as the herdr hook is today.

---

## C: History collection (required)

### Sources

Measured on framework on 2026-10-25. Only paths, sizes, and record keys were read.

| Agent | Store | Format | Size on framework |
|---|---|---|---|
| Claude Code | `~/.claude/projects/<cwd-slug>/<uuid>.jsonl`, plus `subagents/` and `tool-results/` per session | JSONL | 34 MB, oldest file 2026-10-01 |
| pi | `~/.pi/agent/sessions/--<cwd>--/<ts>_<uuid>.jsonl` | JSONL v3 | 400 KB |
| omp | `~/.omp/agent/sessions/<slug>/<ts>_<uuid>.jsonl`, plus `N.bash.log` per session | pi-family JSONL v3 | 263 MB (83 MB JSONL, 177 MB `.log`) |
| codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | JSONL | 2.1 MB |
| opencode | `~/.local/share/opencode/opencode.db` (+ `-wal`) | SQLite | 10.5 MB |
| dsh | `~/.dsh/sessions/` | JSONL, zstd-compressed | none yet |
| hermes (mini) | `/var/lib/hermes/.hermes/state.db` | SQLite with WAL and FTS5 | not measured |

Facts that shape the transport:

- **Claude deletes old transcripts.** `cleanupPeriodDays` defaults to 30. The minimum is 1, and `0` fails validation ([settings reference](https://code.claude.com/docs/en/settings-reference#cleanupperioddays)). The age is the file mtime. The sweep runs in the background after a session starts, at most once a day. On 2026-10-25 the oldest framework file was 24 days old, which agrees with the default. We set it to 120 on that day.
- **Folder names come from paths.** Claude, pi, and omp encode the project path differently, and caya paths start with `/Users`. Keep one tree per host. Do not merge hosts.
- **JSONL files grow during a session.** One push can copy half a file. The next push completes it.
- **SQLite stores** (opencode, hermes) must be copied as a `sqlite3 .backup` snapshot, not as the live file with its WAL.
- **omp `.log` files** are command output, not transcript. Leave them out unless you want them.

### Direction: push, not pull

Each host sends its files to mini. Pull from mini fails for two reasons:

- mini cannot connect into caya.
- A sleeping laptop misses the pull. A push timer runs again when the laptop wakes.

### Archive layout on mini

```text
/srv/agent-sessions/
├── desktop/<agent>/...      # same relative paths as on the host
├── framework/<agent>/...
├── mini/<agent>/...
├── mini-hermes/hermes/...   # hermes state + /var/lib/hermes/.claude/projects
└── caya/...                 # out of scope (D1)
```

- Owner `agent-push`, group `agent-sessions`, mode `0750` (see [§ Push path](#push-path-d4b)). `/srv` is the 2 TB btrfs disk.
- The archive never deletes. A file that the agent removes locally stays in the archive.

### Transport

| Option | How | Fit |
|---|---|---|
| **rsync push timer (recommended)** | systemd user timer on NixOS, launchd agent on caya. `rsync --delay-updates`, no `--delete`. Write-only key with a forced `rrsync -wo /srv/agent-sessions/<host>` command. SQLite stores go as `.backup` snapshots. | The laptop starts every connection, so caya stays closed. A sleeping laptop catches up on wake. |
| Syncthing | Send-only on laptops, receive-only on mini, deletes ignored. | Peers connect into caya on port 22000, which breaks the caya rule. Live SQLite copies can corrupt. |
| agentsview SSH sync | mini pulls from each host over SSH. | Pull: fails for caya and for sleeping laptops. |
| agentsview `pg push --watch` | Each host pushes parsed rows to Postgres on mini. | Works from caya, but stores parsed rows, not raw files. An option for D1 (b). |
| cass `sources` | mini pulls over SSH and rsync. | Pull, same problems as above. |

**SSH gotcha.** mini runs `tailscale up --ssh`. On the tailnet address, Tailscale SSH answers port 22 and ignores `authorized_keys` forced commands. The `rrsync -wo` limit then does not apply. On the LAN address, OpenSSH answers and the limit applies. Options (decide in Phase 0):

1. OpenSSH listens on a second port on `tailscale0` for pushes only. The firewall already trusts `tailscale0`.
2. Pushes run only on the home LAN. framework on the road catches up at home.
3. Accept Tailscale SSH without the forced command, and limit the push user by other means.
4. Turn off Tailscale SSH on mini, so that OpenSSH answers port 22 on the tailnet too.

### Push path (D4b)

Recommendation: option 1.

| Option | Works off the LAN | Write-only key works | Changes to existing access | Verdict |
|---|---|---|---|---|
| 1. Second OpenSSH port on the tailnet | Yes | Yes | None | **Use this.** |
| 2. LAN only | No. framework catches up at home. | Yes | None | Fallback if the tailnet ACL blocks the port. |
| 3. Tailscale SSH, no forced command | Yes | No. A stolen laptop key gets a shell on mini. | None | Reject. |
| 4. Turn off Tailscale SSH on mini | Yes | Yes | All interactive tailnet logins to mini change. | Too large for this plan. |

Design of option 1:

- **Port.** OpenSSH on mini listens on 22 and 2222. On the tailnet address, Tailscale SSH keeps port 22 and OpenSSH gets 2222.
- **Firewall.** Set `services.openssh.openFirewall = false` on mini. Otherwise NixOS opens 2222 on every interface. Port 22 stays open on the LAN through `allowedTCPPorts` in `modules/nixos/networking.nix`. Port 2222 is then open on `tailscale0` only, because that interface is trusted.
- **User.** A dedicated user, for example `agent-push`, owns `/srv/agent-sessions/<host>/`. Add it to `AllowUsers` (`modules/nixos/openssh.nix` allows only jadee today). The user needs a real login shell, because sshd runs the forced command through it.
- **Keys.** One key per host, made on that host, with no passphrase. The public key is a host fact, like `sshAddress`. Each key gets one line in `authorized_keys`:

  ```text
  restrict,command="rrsync -wo -no-del /srv/agent-sessions/<host>" ssh-ed25519 AAAA… agent-push@<host>
  ```

  `restrict` turns off the PTY and all forwarding. `-wo` blocks reads. `-no-del` refuses `--delete`. Do not use `-no-overwrite`, because JSONL files grow and must be overwritten. `rrsync` is in nixpkgs (3.5.0).
- **Client.** The push job connects to mini's tailnet name on port 2222 with its own identity file. It does not use the interactive `mini` alias, which points at the LAN address. On the home LAN, Tailscale connects directly, so one path serves both cases.
- **Read side.** agentsview reads the archive through a shared group, for example `agent-sessions`, with mode `0750` on the folders.

What a stolen laptop key can do: write new files into that host's folder, and overwrite files in it. It cannot read the archive, delete files, open a shell, or reach other hosts' folders. The restic backup keeps the old versions of overwritten files.

Phase 0 test: the tailnet ACL is not in this repo. If it limits ports, it can block 2222. From framework on a different network, run `nc -vz <mini tailnet name> 2222` after the port is open.

### Index and search

| Tool | Reads our agents | Multi-machine | UI | Nix | License, activity |
|---|---|---|---|---|---|
| **agentsview (recommended)** | All seven: Claude, codex, pi, omp, opencode, dsh, hermes `state.db` | Copied folders as `[[session_sources]]` with a machine label ([docs](https://agentsview.io/docs/filesystem-sync/)), SSH pull, or Postgres push | Web UI (`serve --require-auth`), CLI, MCP | `llm-agents.agentsview` in our locked input | MIT. v0.46.1, 2026-10-23 |
| cass | Claude, codex, pi, omp, opencode, hermes. No dsh. | `cass sources` pulls over SSH | TUI, CLI, JSON. No web UI. | None. llm-agents dropped it on 2026-03-03 | MIT with a rider that excludes some AI companies. v0.10.0 |
| claude-code-history-viewer | Claude, codex, opencode, pi, omp | Local folders only | Desktop app, `cchv-server` web UI | None | MIT |
| Agent Sessions | Claude, codex, opencode, pi, hermes, dsh | No | macOS app | None | MIT. A local viewer on caya at most. |
| SpecStory | Several | Its own cloud only | CLI, cloud | None | Not self-hosted |
| ccusage | Token use and cost only | No | CLI | nixpkgs, llm-agents | Not an archive |

Recommendation: agentsview on mini.

- It reads the pushed folders through `[[session_sources]]`, one entry per host and agent, with a machine label.
- mini's own agent folders reach the archive by the same push as the other hosts, so agentsview reads only `/srv/agent-sessions`. A timer that runs as user `hermes` copies a `.backup` snapshot of hermes `state.db` into `/srv/agent-sessions/mini-hermes/hermes/`.
- Its SQLite archive keeps a session after the source file is gone.
- The web UI is at `https://sessions.jadee.fyi` (tailnet only, port 8089 on loopback). No login since 2026-10-26: Caddy answers 403 to clients outside the tailnet (`tailnet-only` snippet), because it also binds the LAN address. agentsview's own auth is a single API token, so it stays off.
- `cleanupPeriodDays` is 120 (was the default 30). It gives time to notice a broken push.

### Backup

Copy the Immich pattern: restic over SFTP to Unraid, a separate repo path, and a daily timer. restic encrypts the repo. The restic password is a new sops secret.

Back up three things:

- `/srv/agent-sessions` (the raw files).
- A `.backup` snapshot of the agentsview `sessions.db`.
- A `.backup` snapshot of hermes `state.db`.

### Privacy

Transcripts contain file contents, command output, and sometimes secrets. The archive is therefore a valuable target.

- Keep the archive `0750`, readable by the `agent-sessions` group only.
- Put the agentsview web UI behind Caddy on the tailnet with authentication, like the hermes dashboard.
- Give each push key a forced command (`rrsync -wo -no-del <dir>`). A stolen laptop key can then write to its own folder only. It cannot read the archive.
- caya is out of scope (D1).

### Work repos on personal hosts

Work sessions are out of scope (D1). A work repo on a personal host, such as `~/git/graphs` (`AMN-DATA`) on framework, still creates sessions. The push sends them to mini, because it has no filter (D10).

How each agent stores the project path decides how easy the filter is:

| Agent | Path in | Filter |
|---|---|---|
| Claude, pi, omp | Folder name (path slug) | An rsync `--exclude` per repo. Each agent spells the slug differently. |
| codex | `cwd` inside the session file, folders by date | A script reads `session_meta` and skips matches. |
| opencode | One SQLite file for all projects | Rows must be filtered, or the whole file stays local. |
| hermes | Not affected | Hermes does not work in work repos. |

Decided (D10): you manage these sessions by hand. The push has no filter.

A work session that reaches mini exists in three places. To remove it, clean all three:

1. The raw files in `/srv/agent-sessions/<host>/`.
2. The agentsview database. It keeps a session after its source file is gone.
3. The restic snapshots on Unraid. Old snapshots keep the files until `restic forget --prune` removes those snapshots.

To keep a work session off mini from the start, delete it on the laptop before the next push, or run that work on caya.

Options that were not picked:

1. **Exclude list in the flake.** `data/agents/session-sources.nix` lists excluded repo folder names, for example `graphs`. The push job turns them into excludes and filters. Static and explicit.
2. **Exclude by `origin` owner.** The push job skips any repo whose `origin` belongs to `AMN-DATA`. Automatic, but the job must map each session back to a repo on disk.
3. **No work repos on personal hosts.** Keep work repos on caya only. No filter. `graphs` moves off framework.
4. **Filter in agentsview.** Exclude projects at index time. Raw files still reach mini. Not verified that agentsview can do this.

---

## D: Status events and telemetry (out of scope)

Notes for later. Nothing in this plan builds D.

| Option | What it gives |
|---|---|
| Agent hooks (`Notification`, `Stop`) post to ntfy on mini | A push message when an agent waits for input, on any host. |
| herdr notifications | herdr already tracks `blocked` and `done`. Its notification CLI can feed ntfy. |
| OpenTelemetry from Claude Code and codex to mini | Cost, token, and tool metrics in Grafana. mini has Tempo for traces only. Logs and metrics need Loki and a metrics store. |

Rule for now: keep host names and agent names in the archive identical to the names that D will use later.

## E: Claude Remote Control

It stays on. It covers Claude sessions only and routes through Anthropic. This plan does not change it.

---

## Phases

### Phase 0: decisions and tests (no deploy)

All decisions have answers (2026-10-25). Phase 0 has tests and small moves left.

1. Test the push port: after port 2222 is open, run `nc -vz <mini tailnet name> 2222` from framework on a different network. If the tailnet ACL blocks it, fall back to LAN only.
2. Test D7: add a Tailscale SSH `accept` rule for one host pair. Run `ssh -o BatchMode=yes <host> true` from the other host.
3. Record which files `herdr integration install` and `tuios integration install` write. On these hosts, `~/.claude/settings.json` is a live symlink into the flake checkout.
4. Done 2026-10-25: a local test of the push and of agentsview on framework.
5. Run the herdr and tuios trial (D2).
6. Done 2026-10-25: the remote-edit rule in the flake `AGENTS.md` (D8).
7. Move `~/Git` to `~/git` on framework, and on desktop if it has one (D9). Update the noctalia path.

### Phase 1: C, the archive

1. Done 2026-10-25: `cleanupPeriodDays = 120` in `data/agents/global/settings.json`. Other hosts get it when their checkout has the commit.
2. Written 2026-10-25 on branch `agent-sessions`, not deployed:
   - `hosts/mini/services/agent-sessions.nix`: push receiver (user `agent-push`, port 2222, `rrsync -wo -no-del`), hermes snapshot timer, agentsview, Caddy vhost, restic backup.
   - `modules/profiles/devenv/agents/session-push.nix`: push timer on every Linux host, mini included.
   - `data/agents/session-sources.nix`: the source list. `dotfilesLib` now exports `hostFacts` and `agentSessionSources`.
3. Tested locally: rsync with the push flags against `rrsync -wo -no-del` (12 checks), and two agentsview starts with the generated `config.toml`.

Rollout, in this order:

1. Add `mini/backup/agent-sessions-restic-password` to `secrets/secrets.yaml`. A missing key fails the mini switch.
2. On Unraid: `mkdir -p /mnt/user/backup/agent-sessions`.
3. Switch desktop, framework, and mini. Each switch makes `~/.ssh/agent_push_ed25519`. No timer runs yet.
4. Copy each `~/.ssh/agent_push_ed25519.pub` into its `hosts/<host>/host.nix` as `agentPushKey`.
5. Switch mini, then the other hosts. The timers start.
6. Run `flake mini dns-sync` for `sessions.jadee.fyi`.
7. Phase 0 test: `nc -vz mini.quokka-qilin.ts.net 2222` from framework off the LAN.
8. Check: `systemctl --user status agent-session-push` on each host, `ls /srv/agent-sessions` on mini, and the web UI.

### Phase 2: A, mini as agent host

1. Add the herdr server service on mini, with a memory limit.
2. Install the herdr integrations on mini.
3. Add the git identity and the GitHub token on mini. Repos come from `work --on mini` (Phase 3).
4. Log in to each agent on mini once.
5. Run `herdr machine add mini` on each laptop. Set up the phone SSH app.

### Phase 3: mode selection

1. Add the `work` command with `--on local|mini|hermes`.
2. Make `--on mini` clone a missing repo on mini to the same path.

### Phase 4: B, live view (optional)

1. Apply D7 for the host pairs that need it.
2. Save the other hosts as herdr machines on each viewer.

### Phase 5: H, hermes delegation

1. Add `claude-code`, `codex`, `tmux`, and `git` to `services.hermes-agent.extraPackages`.
2. Log in to Claude for user `hermes`, or add an API key to `hermes.env`.
3. Give hermes a work folder with worktrees per task.
4. Add hermes and its coding agents to the archive sources, if Phase 1 did not.

### Later: D

---

## File sketch

| File | Purpose |
|---|---|
| `data/agents/session-sources.nix` | Agent name → session folders, relative to `$HOME`. One list for push, index, and backup. |
| `modules/profiles/devenv/agents/session-push.nix` | HM: systemd user timer (Linux) or launchd agent (Darwin) that pushes to mini. |
| `modules/profiles/devenv/agents/session-manager.nix` | HM: config of the D2 tool (herdr or tuios). The server unit for hosts that need it. |
| `modules/profiles/devenv/agents/work.nix` | HM: the `work` command. Also creates `~/git` (D9). |
| `modules/profiles/desktop/noctalia/config/settings.toml` | Path `~/Git/community-plugins` becomes `~/git/community-plugins` (D9). |
| `AGENTS.md` | New text for the remote-edit rule (D8). |
| `hosts/mini/services/agent-sessions.nix` | Archive folder, push receiver, agentsview service and `[[session_sources]]`, hermes snapshot job, restic backup. |
| `hosts/mini/services/caddy.nix` | A tailnet-only vhost for the agentsview web UI. |
| `hosts/mini/services/hermes.nix` | Extra packages and credentials for delegation (Phase 5). |
| `lib/default.nix` | Add `session-sources.nix` to `agentDataFiles` if modules read it live. |
| `docs/hosts/mini.md` | Ops notes after the build: restore, rotate keys, reindex. |
| `docs/adr/` | One ADR after Phase 0: "mini is the hub for agent sessions". |

## Secrets touchpoints

| Secret | Where |
|---|---|
| Push key per host | Private key on each host, made there. The public key goes into the `authorized_keys` of `agent-push` on mini, with `restrict` and `rrsync -wo -no-del`. Public keys are not secret. |
| restic password for the archive | New sops secret on mini. |
| Agent logins on mini | Interactive, stored by each agent. Not in sops. |
| Claude access for user `hermes` | OAuth once, or an API key through sops into `hermes.env`. |
| GitHub token on mini for jadee | sops. `agent_pat` exists for hermes. Decide if jadee on mini uses the same token. |

## Risks

| Risk | Mitigation |
|---|---|
| The archive holds secrets from transcripts. | `0750` with a dedicated group, write-only push keys, encrypted backup, no public UI. |
| Work sessions from personal hosts reach the archive and the backup (D10, manual). | Clean the raw files, the agentsview database, and the restic snapshots. Or run work on caya. |
| The flake checkouts on desktop and mini diverge (D8). | Push from mini when a session ends. Pull before a session on the other host. |
| Agents and their builds use the memory that llama.cpp needs. | `MemoryMax` on the herdr service. Heavy Nix builds stay on desktop. |
| Tailscale SSH check mode blocks herdr background connections. | D7: `accept` rules for the host pairs. Phase 0 test. |
| Claude deletes transcripts older than `cleanupPeriodDays` (30) before a push. | Set to 120 on 2026-10-25. The push interval is much shorter than any cleanup period. The archive never deletes. |
| A copy of a live SQLite file with its WAL is corrupt. | Copy only `sqlite3 .backup` snapshots. |
| Tailscale SSH ignores the forced `rrsync` command. | D4b: a second OpenSSH port for pushes. |
| herdr is young (0.9.x). Releases are frequent. | Pin through `llm-agents`. Client and server versions do not have to match. |
| Hermes runs agents without permission prompts. | Worktrees only, user `hermes`, nono profiles where possible. |

## Success criteria

- A search on mini finds sessions from desktop, framework, mini, and hermes. A new session shows up within one push interval.
- A restic snapshot of the archive exists on Unraid for each day.
- From framework and from the phone, `herdr` shows mini's workspaces and agent states.
- `work --on mini` in a local repo opens a session on mini in the same path, and clones the repo there if it is missing.
- After a mini reboot, the herdr layout returns and Claude sessions resume.
