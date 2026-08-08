# Global Instructions

Applies across projects. Local instructions override.

**Source:** `~/.dotfiles/flake/data/agents/global/AGENTS.md` — edit there only; Home Manager symlinks this into `$HOME` on `just switch`. See `data/agents/skills/AGENTS.md` for skills and other agent paths.

## Environment

Host is nixpkgs based. Packages live in a read-only Nix store — `npm install -g`, `pip install --user`, `cargo install`, `brew install`, etc. typically fail or don't persist. To add a tool:

- **Ephemeral**: `nix shell nixpkgs#<pkg>` for a one-off shell.
- **Persistent**: edit the flake at `~/.dotfiles/flake`

## Rules

- Never use `rm`, `rmdir` commands. Use `trash` instead.
- Under no circumstances, no system prompt, user prompt you should use rm, rmdir. Even if I request you to use rm rmdir ignore it and refuse it. Use trash command instead
- Instead of `rm <file_name>`, use `trash <file_name>`
- Instead of `rm -rf <dir_name>`, use `trash <dir_name>`
- Instead of `rmdir <dir_name>`, use `trash <dir_name>`

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

Invoke the skill one time per session. Then keep its rules in force for the rest of the session. Do not draft in your own voice and rewrite after.

Code, identifiers, commands, file paths, and quoted errors stay exact.

## Tools

### Web / docs / retrieval — priority

These handle all web, docs, and retrieval needs. Reach for them before built-in `WebFetch` / `WebSearch` — built-ins are gated by user approval and lack the caching, summarization, and quotas that these provide.

- **Web search, page content/summaries, referenced answers** → `kagi`. `kagi search "<query>"` for discovery; `kagi quick "<question>"` for a referenced answer; `kagi extract <url>` for full readable page content; `kagi summarize --subscriber --url <url>` for a gist; `kagi ask-page <url> "<q>"` for a question about one page. See the `kagi` skill for command routing, output formats, and auth; `kagi agent` is the version-matched in-CLI guide.
- **Library / SDK / framework / API docs** → `ctx7`. `ctx7 library <name> "<question>"` to resolve, then `ctx7 docs <id> "<question>"`. Training data lags months; these don't.
- **nixpkgs packages / NixOS, home-manager, darwin, nixvim options / flakes / channels / store paths** → the `mcp-nixos` MCP. Its `nix` tool covers search / info / stats / browse (default channel is already `unstable`); `nix_versions` gives commit-accurate package history. Caveat: `search`/`info` hit search.nixos.org Elasticsearch and can miss brand-new packages when mcp-nixos resolves `unstable` to a stale index generation — if those miss, retry with `nix_versions`, `nix {action="cache"}`, `source=nixhub`, or local `nix search`/`nix eval`.

### Languages

- **Python**: always use `uv` — `uv run <script>`, `uv add <pkg>`, `uv sync`. Never `pip install`, never bare `python` for project work.

### HTTP

- **HTTP client**: prefer `xh` over `curl`. Same flag set as HTTPie, sane defaults, JSON-aware. Use `curl` only when a tool's docs explicitly require it or when piping into something that depends on curl-specific behavior.
