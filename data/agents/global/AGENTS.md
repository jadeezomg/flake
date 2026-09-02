## Environment

Host is nixpkgs based. Packages live in a read-only Nix store — `npm install -g`, `pip install --user`, `cargo install`, `brew install`, etc. typically fail or don't persist. To add a tool:

- **Ephemeral**: `nix shell nixpkgs#<pkg>` for a one-off shell.
- **Persistent**: edit the flake at `~/.dotfiles/flake`

## Rules

- Never use `rm`, `rmdir` commands. Use `trash` instead.
- Never game verification — don't weaken assertions, narrow scope, reduce coverage, or skip checks to get a pass.
- If checks already fail, state that and don't attribute the failure to your work.
- If verification fails after a change, make one targeted fix when the cause is clear; otherwise stop and report.
- Don't rewrite files when a CLI move/rename works. Use `mv` (or `git mv` inside a repo) to preserve history, avoid drift.
- Always edit config/source on the host you are running on (the local checkout). Never change configs over SSH on remote hosts — leave remote edits for the user to review and approve locally first. Remote hosts are for inspection and deploy/ops only.

### Secrets and sensitive data

- Never print or use commands that expose secrets (tokens, private keys, credentials) to terminal output.
- Prefer existing authenticated CLIs; redact sensitive strings in any displayed output.

## Uncertainty

Ask before changes to behavior, API, UX, naming, persistence, auth, dependencies, or config. One targeted question; if bundling, each must be independently answerable. When proceeding under low-risk ambiguity, state the assumption.

## Evidence

Gather evidence proportional to risk. For behavior/API/infra changes, trace execution path and regression surface before editing. Prefer external verification over self-review — a fresh test beats re-reading your own code.

## Writing

Invoke the `simple-english` skill before you write prose. This rule covers three targets:
- Code comments and docstrings.
- Documentation: `README.md`, `AGENTS.md`, ADRs, skills, commit and PR messages.
- Replies, status reports, and questions that the user reads.

## Tools

### Web / docs / retrieval — priority

These handle all web, docs, and retrieval needs. Reach for them before built-in `WebFetch` / `WebSearch` — built-ins are gated by user approval and lack the caching, summarization, and quotas that these provide.

- **Web search, page content, referenced answers** → `kagi`: `search "<q>"` to discover, `quick "<q>"` for a referenced answer, `extract <url>` for full page text, `summarize --subscriber --url <url>` for a gist, `ask-page <url> "<q>"` to question one page. For anything else — AI, Assistant, batch, account config — run `kagi agent`. It is embedded in the binary and version-matched, so read it instead of guessing a flag. 
- **Library / SDK / framework / API docs** → `ctx7`: `ctx7 library <name> "<q>"` to resolve, then `ctx7 docs <id> "<q>"`. Your training data lags months behind; these do not.
- **nixpkgs packages / NixOS, home-manager, darwin, nixvim options / flakes / channels / store paths** → the `mcp-nixos` MCP. Its `nix` tool covers search / info / stats / browse (default channel is already `unstable`); `nix_versions` gives commit-accurate package history. Caveat: `search`/`info` hit search.nixos.org Elasticsearch and can miss brand-new packages when mcp-nixos resolves `unstable` to a stale index generation — if those miss, retry with `nix_versions`, `nix {action="cache"}`, `source=nixhub`, or local `nix search`/`nix eval`.

### Languages

- **Python**: always use `uv` — `uv run <script>`, `uv add <pkg>`, `uv sync`. Never `pip install`, never bare `python` for project work.
