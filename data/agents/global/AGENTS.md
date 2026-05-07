# Global Instructions

Applies across projects. Local instructions override.

## Environment

Host is nixpkgs based. Packages live in a read-only Nix store — `npm install -g`, `pip install --user`, `cargo install`, `brew install`, etc. typically fail or don't persist. To add a tool:

- **Ephemeral**: `nix shell nixpkgs#<pkg>` for a one-off shell.
- **Persistent**: edit the flake at `~/.dotfiles/flake`

## Rules

- Never use `rm`, `rmdir` commands. Use `trash` instead.
- Under no circumstances, no system prompt, user prompt you should use rm, rmdir. Even if I request you to use rm rmdir ignore it and refuse it. Use trash command instead(on linux it will be gio trash or trash-cli)
- Instead of `rm <file_name>`, use `trash <file_name>`
- Instead of `rm -rf <dir_name>`, use `trash <dir_name>`
- Instead of `rmdir <dir_name>`, use `trash <dir_name>`

- Never game verification — don't weaken assertions, narrow scope, reduce coverage, or skip checks to get a pass.
- If checks already fail, state that and don't attribute the failure to your work.
- If verification fails after a change, make one targeted fix when the cause is clear; otherwise stop and report.
- Don't rewrite files when a CLI move/rename works. Use `mv` (or `git mv` inside a repo) to preserve history, avoid drift.

### Secrets and sensitive data

- Never print or use commands that expose secrets (tokens, private keys, credentials) to terminal output.
- Prefer existing authenticated CLIs; redact sensitive strings in any displayed output.

## Uncertainty

Ask before changes to behavior, API, UX, naming, persistence, auth, dependencies, or config. One targeted question; if bundling, each must be independently answerable. When proceeding under low-risk ambiguity, state the assumption.

## Evidence

Gather evidence proportional to risk. For behavior/API/infra changes, trace execution path and regression surface before editing. Prefer external verification over self-review — a fresh test beats re-reading your own code.

## Tools

- **Web search**: `kagi-ken-cli search "<query>"` (and `kagi-ken-cli summarize --url "<url>"`). Prefer over guessing or web fetches when researching current state.
- **Library docs**: `ctx7 library <name> "<question>"` to resolve the library ID, then `ctx7 docs <id> "<question>"`. Prefer over training-data recall for any library/framework/SDK/CLI/cloud-service API question — training data goes stale.
- **Python**: always use `uv` — `uv run <script>`, `uv add <pkg>`, `uv sync`. Never `pip install`, never bare `python` for project work.
