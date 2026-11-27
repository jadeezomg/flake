---

name: orchestrate
description: Run several interactive agent sessions in herdr worktrees for the user, in the herdr TUI or in Herdr.app. Pick independent work, start each session with a brief, keep the user in the loop, then review, land and clean up. Use when the user asks to start agents or sessions, or to pick work for agents. Also use it to check on sessions, to land or merge their work, or to clean up sessions and worktrees.
---

# Orchestrate agent sessions

You are the orchestrator. You start agent sessions in herdr: one task, one worktree, one session each. The user stays in the loop. Each session works with the user, and you never decide in the user's place.

**Edit this skill in the flake only:** `data/agents/skills/local/orchestrate/`. APM installs it on `flake switch`.

Run `herdr --skill` once for the herdr command reference. The `terminal-browser` and `request-review` skills cover their own commands.

The steps below use the herdr TUI (`$HERDR_PANE_ID` is set). If `$HC_TERMINAL_ID` is set, you run in Herdr.app. Then use the commands of [Herdr app](#herdr-app) in each step.

## Rules for every step

- **The user decides.** Ask through the ask tool: which tasks, the scope, each design question, and each step that changes something outside a worktree.
- **Sessions understand first.** A session starts with a summary of its issue, its problems and its open questions. It changes nothing before the user agrees with its plan.
- **Sessions are interactive.** Every brief carries the interaction contract of [`references/brief.md`](references/brief.md).
- **The user answers each question of a session.** A session can wait at a question or an approval. Then tell the user which pane waits, and the answer that fits the user's earlier decision. Do not answer it yourself.
- **Web work is visible.** Follow the browser rule below, and put it into every brief.
- **Models.** Follow the model rule below.
- **Improve this skill.** After a few rounds of sessions, or after a problem that cost time, propose a change of this skill to the user. Say what happened and which line to add or change. Edit the skill only after a yes.

## 1. Pick the work

1. Read the open tasks in the tracker, and the running sessions (`herdr agent list`, `git worktree list`).
2. Sort each task: code without a live system, live work that needs the user's yes at each step, or work that only a person can do.
3. Build sets of tasks whose files do not overlap with each other or with a running session. Read each issue and the code it touches.
4. Give the user 2 to 4 options, with one recommendation, through the ask tool. Name the model of each task.

## The model rule

The user chooses your own model. Do not change it, and do not ask the user to change it.

Each session that you start runs Opus or Sonnet. You choose the model for each task:

- `opus`: open design questions, a wide or unclear scope, several systems, live systems (a deploy, data, a recipe), security, a migration, or a hard bug.
- `sonnet`: a clear scope with a testable "Done means", for example a small fix, a test, a doc or config change, or a mechanical refactor.
- If you are not sure, choose `opus`. The user can change your choice.

## 2. Start a session

1. Make the worktree from the repo's parent herdr workspace: `herdr worktree create --workspace <parent> --branch <issue>-<slug> --base origin/<branch> --label <branch> --no-focus`. A repo with no herdr workspace: `git worktree add -b <branch> <path> origin/<branch>`, then `herdr workspace create --cwd <path> --label <branch> --no-focus`. If a clone holds someone's uncommitted work, leave it alone.
2. Set the upstream (`git branch -u origin/<branch>`). Copy the gitignored state that the task needs, as the repo's `AGENTS.md` says.
3. Start the agent in the root pane: `herdr agent start <issue-id> --kind claude --pane <pane> -- --permission-mode <the user's mode> --model <opus or sonnet>`.
4. Write the brief from [`references/brief.md`](references/brief.md) into your scratchpad. Send it with `herdr agent prompt <issue-id> "$(cat <file>)"`, then check that `herdr agent get <issue-id>` shows `working`.
5. Tell the user the agent, workspace, worktree, task and model, and what the session will ask them.

## 3. Watch

- The status of `herdr agent get` lags, so `working` can mean done. Read the pane: `herdr pane read <pane> --source recent-unwrapped --lines 80`.
- `agent_blocked` from `herdr agent prompt` means that a question waits. Read it with `herdr agent read <name> --source visible`, and tell the user.
- Dim text in a session's input box is Claude Code's suggested next prompt, not the user's input. `herdr pane read <pane> --format ansi` shows it as dim (`\e[2m`).
- To pass a decision or a change of plan: `herdr agent prompt <name> "From the orchestrator, with the user's decision: …"`.
- When a session finishes, read its whole report, and check the commits and files that it names.

## 4. Review and land

1. Review each finished change before it lands. The session runs `request-review` (an omp reviewer in its own pane), or you start a review subagent with the diff and no conclusion of yours. A requested review is open until its report arrives. Read the report, and check that the agreed fixes passed the checks. The user decides each Must fix finding that is still open. Land only after that.
2. Check for conflicts: the changed files of each branch (`git diff --name-only <base>...<branch>`) and `git merge-tree --write-tree`. A rename in one branch can break the new code of another without a text conflict.
3. Land in a worktree of the target branch. If the base did not move, fast-forward. Else cherry-pick, or merge as the repo does. Keep the intent of both sides in each conflict.
4. Run the repo's full checks on the combined state. Fix only what the combination broke, in its own commit.
5. Push after the user's yes ("merge" and "land" count as yes). Close the task in the tracker with a comment: the commits, the checks, and what stays open.

## 5. Clean up

1. Clean up only a finished session: its report is done, no question waits, and its work landed or is pushed.
2. Check the worktree: `git status --porcelain` is empty, and the target holds each commit (`git merge-base --is-ancestor`, or `git cherry` and `git range-diff` after a cherry-pick). Keep a worktree that holds untracked files of the user, and tell the user.
3. Copy the gitignored state that other work still needs.
4. Close the session with `herdr agent prompt <name> "/exit"` (in Herdr.app, see the table row "Close the session"). Read `claude --resume <id>` from the pane, and record it with the open item in your scratchpad.
5. Remove the worktree: `herdr worktree remove --workspace <ws>`, or `herdr workspace close <ws>` and `git worktree remove <path>` for a plain git worktree. Then run `git worktree prune`, and delete the branch once the target holds it.

## The browser rule

A web object is a sheet, a recipe, an issue, a file or a web app. If a session works on one, it opens the object in terminal-browser. This also applies to work through an MCP or an API:

1. Open the object beside the session: `terminal-browser open <url> --split right --size 0.4`. This makes a herdr pane in the session's tab. Open a second object with `terminal-browser new-tab <url>`.
2. Keep the active tab on the object that you change. After each write, run `terminal-browser action -- reload`, so the user sees the change.
3. The user logs in. Each page action that changes data needs the user's yes. Read the page with `snapshot` and `get`.
4. When you are done with the browser, run `terminal-browser action done`. Leave the pane open for the user.

In Herdr.app, steps 1 and 2 need other commands. herdr-core sets `TERM_PROGRAM=ghostty` in each terminal. terminal-browser then fails its graphics test, and it looks for a Ghostty pane that does not exist. The page still draws in a Herdr pane. The Browser section of [`references/brief.md`](references/brief.md) gives the Herdr.app commands, and agent-browser as the fallback. `PIXEL_SKIP_GRAPHICS_CHECK` is internal to terminal-browser (tested with 0.15.9). If a terminal-browser update breaks it, use agent-browser.

### Linear

`open -a Linear <linear.app url>` opens an issue or a project in the Linear app. The app takes the focus each time, also with `open -g`. So open it only in these cases, in which the user must read the whole issue:

1. Before the user says yes to a new issue, a new description, or a status change such as closing.
2. When a question to the user depends on the text of the issue or its plan.
3. When the user asks to see the issue.

In all other cases, give the issue id and its URL in the chat. The app shows each change live, so it needs no reload.

## Herdr app

Herdr.app shows spaces, tabs and panes. herdr-core (`hc`) runs their terminals. `herdr-app` changes what the user sees, and `hc` starts, reads and messages agents. Run `herdr-app --skill` and `hc --skill` once. `<t>` is the session name (`--name <issue-id>`) or its terminal address (`t7`).

| Step                           | herdr TUI                                                     | Herdr.app                                                                                                                                                                                 |
| ------------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Running sessions               | `herdr agent list`                                            | `hc ls`, `herdr-app ls`                                                                                                                                                                   |
| Make the worktree              | `herdr worktree create …`                                     | `git -C <repo> worktree add -b <branch> ~/.herdr/worktrees/<repo>/<branch> origin/<base>` (the path of the app's own worktree dialog, with `/` in the branch as `-`)                      |
| Start the agent with the brief | `herdr agent start …`, then `herdr agent prompt …`            | The steps in [Start a session in Herdr.app](#start-a-session-in-herdrapp)                                                                                                                 |
| Status                         | `herdr agent get <name>`                                      | `hc get <t>`, or `hc wait --children any` for the next news of any session                                                                                                                |
| Read the session               | `herdr pane read <pane> --source recent-unwrapped --lines 80` | `hc read <t> --lines 80`                                                                                                                                                                  |
| A question waits               | `agent_blocked`                                               | `hc get <t>` shows `blocked`, and `hc send` exits with code 9                                                                                                                             |
| Send a decision                | `herdr agent prompt <name> "…"`                               | `hc send <t> "…"`                                                                                                                                                                         |
| Close the session              | `herdr agent prompt <name> "/exit"`                           | `hc keys <t> / e x i t`, then `hc keys <t> enter`, then `hc read <t> --lines 40` for the resume id. See the note below the table.                                                         |
| Remove the worktree            | `herdr worktree remove --workspace <ws>`                      | `herdr-app do space.close '{"id":"<sp>","confirmed":true}'` ends the session and its shell. Then `git -C <repo> worktree remove <worktree>`, `hc rm <issue-id>` and `hc rm <issue-id>-sh` |

- Do not close a session with `hc send <t> "/exit"`. The session gets the text inside `<hc from="…">`, so Claude reads it as a message and does not exit. If the session runs a tool, press `hc keys <t> esc` first.
- `hc rm` takes one terminal per call. If `hc ls` no longer lists the terminal, skip it.

### Start a session in Herdr.app

1. Make two new ids, and record them: `sp=sp$(openssl rand -hex 16)` and `tb=tb$(openssl rand -hex 16)`.
2. Start the agent with the brief. Write the issue id in lower case, because hc names allow only `a-z 0-9 - _`:
   `hc run --bg --outlive-parent --name <issue-id> --cwd <worktree> --label herdr.space=$sp --label herdr.tab=$tb --label task=<issue-id> claude --permission-mode <mode> --model <opus or sonnet> "$(cat <brief>)"`
3. Open the user's shell beside it, in the same tab:
   `hc run --bg --no-parent --name <issue-id>-sh --cwd <worktree> --label herdr.space=$sp --label herdr.tab=$tb --label task=<issue-id>`
   The user runs commands and checks progress there. The session opens terminal-browser and tuicr reviews there, as the brief says. Put the shell's name into the brief.

- The session is your child, because you start it with `hc run` from your own terminal. The agents list shows it under you. If a child blocks, fails or exits, herdr-core types a note into your session. If your session ends, `--outlive-parent` keeps the child running. The shell has no parent, so it sends no notes.
- The new ids make Herdr open a new space for the worktree. The space has no name, so it nests under its repo, as the spaces of the worktree dialog do. Without the labels, a terminal gets no pane.
- `hc ls --label task=<issue-id>` lists the session and its shell.
- At the start, pin your own session to the top of the agents list: `herdr-app do terminal.pin "$(jq -n --arg t "$HC_TERMINAL_ID" '{terminal:$t, pinned:true}')"`.
- When a session waits for the user, show it to the user: `herdr-app do terminal.peek "$(jq -n --arg t "$(hc get <issue-id> --json | jq -r .address)" '{terminal:$t}')"`. `terminal.peek` takes the address (`t7`), not the name.
- When a session's report is done and only the landing is left, settle its tab: `herdr-app do tab.settle '{"id":"<tb>"}'`. If the session needs the user again, the tab comes back.
- `hc send` waits while the user types a draft in that session. The session sees your text inside `<hc from="<your t>">`.
- terminal-browser needs other commands in Herdr.app. [The browser rule](#the-browser-rule) explains why.

## Gotchas

- A tracker can turn a session name such as `se-1158` into an issue link. Write "the session in the worktree `<name>`".
- The auto-mode classifier blocks a push that looks like a production deploy. Give the user the exact command to run with the `!` prefix.
- State outside a worktree (an installed plugin copy, a cache, a shared test library) is shared by all sessions. Name it in each brief that touches it.
