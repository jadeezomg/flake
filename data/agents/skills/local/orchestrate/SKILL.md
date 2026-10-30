---
name: orchestrate
description: Run several interactive agent sessions in herdr worktrees for the user. Pick independent work, start each session with a brief, keep the user in the loop, then review, land and clean up. Use when the user asks to start agents or sessions, or to pick work for agents. Also use it to check on sessions, to land or merge their work, or to clean up sessions and worktrees.
---

# Orchestrate agent sessions

You are the orchestrator. You start agent sessions in herdr: one task, one worktree, one session each. The user stays in the loop. Each session works with the user, and you never decide in the user's place.

**Edit this skill in the flake only:** `data/agents/skills/local/orchestrate/`. APM installs it on `flake switch`.

Run `herdr --skill` once for the herdr command reference. The `terminal-browser` and `request-review` skills cover their own commands.

## Rules for every step

- **The user decides.** Ask through the ask tool: which tasks, the scope, each design question, and each step that changes something outside a worktree.
- **Sessions understand first.** A session starts with a summary of its issue, its problems and its open questions. It changes nothing before the user agrees with its plan.
- **Sessions are interactive.** Every brief carries the interaction contract of [`references/brief.md`](references/brief.md).
- **The user answers each question of a session.** A session can wait at a question or an approval. Then tell the user which pane waits, and the answer that fits the user's earlier decision. Do not answer it yourself.
- **Web work is visible.** Follow the browser rule below, and put it into every brief.
- **Improve this skill.** After a few rounds of sessions, or after a problem that cost time, propose a change of this skill to the user. Say what happened and which line to add or change. Edit the skill only after a yes.

## 1. Pick the work

1. Read the open tasks in the tracker, and the running sessions (`herdr agent list`, `git worktree list`).
2. Sort each task: code without a live system, live work that needs the user's yes at each step, or work that only a person can do.
3. Build sets of tasks whose files do not overlap with each other or with a running session. Read each issue and the code it touches.
4. Give the user 2 to 4 options, with one recommendation, through the ask tool.

## 2. Start a session

1. Make the worktree from the repo's parent herdr workspace: `herdr worktree create --workspace <parent> --branch <issue>-<slug> --base origin/<branch> --label <branch> --no-focus`. A repo with no herdr workspace: `git worktree add -b <branch> <path> origin/<branch>`, then `herdr workspace create --cwd <path> --label <branch> --no-focus`. If a clone holds someone's uncommitted work, leave it alone.
2. Set the upstream (`git branch -u origin/<branch>`). Copy the gitignored state that the task needs, as the repo's `AGENTS.md` says.
3. Start the agent in the root pane: `herdr agent start <issue-id> --kind claude --pane <pane> -- --permission-mode <the user's mode>`.
4. Write the brief from [`references/brief.md`](references/brief.md) into your scratchpad. Send it with `herdr agent prompt <issue-id> "$(cat <file>)"`, then check that `herdr agent get <issue-id>` shows `working`.
5. Tell the user the agent, workspace, worktree and task, and what the session will ask them.

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
4. Close the session with `herdr agent prompt <name> "/exit"`. Read `claude --resume <id>` from the pane, and record it with the open item in your scratchpad.
5. Remove the worktree: `herdr worktree remove --workspace <ws>`, or `herdr workspace close <ws>` and `git worktree remove <path>` for a plain git worktree. Then run `git worktree prune`, and delete the branch once the target holds it.

## The browser rule

A web object is a sheet, a recipe, an issue, a file or a web app. If a session works on one, it opens the object in terminal-browser. This also applies to work through an MCP or an API:

1. Open the object beside the session: `terminal-browser open <url> --split right --size 0.4`. This makes a herdr pane in the session's tab. Open a second object with `terminal-browser new-tab <url>`.
2. Keep the active tab on the object that you change. After each write, run `terminal-browser action -- reload`, so the user sees the change.
3. The user logs in. Each page action that changes data needs the user's yes. Read the page with `snapshot` and `get`.
4. When you are done with the browser, run `terminal-browser action done`. Leave the pane open for the user.

### Linear

`open -a Linear <linear.app url>` opens an issue or a project in the Linear app. The app takes the focus each time, also with `open -g`. So open it only in these cases, in which the user must read the whole issue:

1. Before the user says yes to a new issue, a new description, or a status change such as closing.
2. When a question to the user depends on the text of the issue or its plan.
3. When the user asks to see the issue.

In all other cases, give the issue id and its URL in the chat. The app shows each change live, so it needs no reload.

## Gotchas

- A tracker can turn a session name such as `se-1158` into an issue link. Write "the session in the worktree `<name>`".
- The auto-mode classifier blocks a push that looks like a production deploy. Give the user the exact command to run with the `!` prefix.
- State outside a worktree (an installed plugin copy, a cache, a shared test library) is shared by all sessions. Name it in each brief that touches it.
