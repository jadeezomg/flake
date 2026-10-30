# Session brief

Fill in each `<…>`. Keep the fixed sections as they are: understand first, work with the user, the browser rule, the review and the report. A short brief that names its sources beats a long one that copies them.

```markdown
# Your task: <issue id> (<short title>)

Read first: <issue id> with its comments, <plans, ADRs, docs and code paths>.

Done means: <the result, from the issue, in today's names>.

## Your files

You own <paths>. Other sessions work at the same time:
- <session> (worktree <name>): <task>, <paths>.
If you must change a file of another session, stop and ask the user.

## Understand first

Change nothing before the user agrees with your understanding and your plan.
1. Read the issue with its comments, its plan, the decisions it names, and the code that it touches.
2. Give the user a summary of 10 to 20 lines: what the issue asks for, why, which files and systems it touches, and how large the change is.
3. Test the issue itself. Is it still true for today's code and names? Is part of it already done? Does it conflict with a decision or another issue? Is "Done means" testable? Does it fix the cause or only a symptom?
4. List the problems and risks that you found. Ask the questions that only the user can answer, through the ask tool.
5. Propose your plan, and wait for the user's go-ahead.

If the issue does not make sense as written, say so. Propose a new text for the issue, and change the tracker only after a yes.

## Work with the user

You work with the user, not in place of the user.
1. Ask through the ask tool whenever the code, the docs and the tracker leave a choice open. Ask, and do not guess.
2. Ask before each commit, each push, each change outside this worktree (a sheet, a recipe, a table, a deploy) and each tracker change. Show what it changes.
3. After each part of the task, report in 2 or 3 lines what you did and what comes next.

## Browser

Each web object that you work on (a sheet, a recipe, an issue, a file, a web app) goes into terminal-browser, also when you work through an MCP or an API:
- `terminal-browser open <url> --split right --size 0.4` for the first object, `terminal-browser new-tab <url>` for the next.
- Keep the active tab on the object that you change, and run `terminal-browser action -- reload` after each write.
- The user logs in. Each page action that changes data needs the user's yes.
- At the end, run `terminal-browser action done`, and leave the pane open.
- A Linear issue goes into the Linear app (`open -a Linear <linear.app url>`), not into terminal-browser. The app takes the focus, so open it only when the user must read the whole issue: before a yes to a new issue, a new description or a status change, when your question depends on the issue text, or when the user asks. Else give the issue id and its URL in the chat.

## Review

When your change is done and its checks pass, request a review with the `request-review` skill. Wait for its report. Fix the findings that you agree with, and run the checks again. Tell the user which findings you fixed. Name each Must fix finding that you did not fix, with your reason: the user decides it.

## Setup

<setup commands, the checks, the shared state to leave alone, and who pushes: you after a yes, or the orchestrator>

## Report

When you are done, stop and report: what you did, the check results with their output, what stays open, and the tracker comment that you propose.
```
