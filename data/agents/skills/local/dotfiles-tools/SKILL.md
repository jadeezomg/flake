---
name: dotfiles-tools
description: Reference for all CLI tools and development preferences in jadee's dotfiles flake. Use this skill whenever helping with shell tasks, writing scripts, recommending tools, or answering "what tool should I use for X". Covers NixOS (desktop/framework) and macOS (caya). Always prefer the tools and methods here over generic alternatives. Trigger when the user is working in a terminal, asking about file operations, text processing, git, development workflows, or system administration.
---

# Dotfiles CLI Tools & Development Preferences

**Edit this skill in the flake only:** `data/agents/skills/local/dotfiles-tools/` (including `references/`). Do not edit `~/.claude/skills/dotfiles-tools/` — APM installs it from the flake on `flake switch`.

For platform-specific tools, read `references/nixos.md` (NixOS) or `references/darwin.md` (macOS).
The full shared tool list is in `references/shared-tools.md`.

## Preferred Development Methods

### Python
- **Always use `uv`** - never `pip`, `pip3`, or `poetry`
- `uv add <pkg>` to add dependencies, `uv run <script>` to run, `uv sync` to install
- `ruff` for linting and formatting (not black/flake8), `ty` for type checking

### Nix
- Format with `flake fmt` (treefmt, deadnix, ruff, ty, biome), never leave a file unformatted
- Lint with `flake lint` (deadnix, statix, deep-import check)
- Use `flake switch` / `flake switch-fast` - never bare `nixos-rebuild`, `darwin-rebuild`, or `nh`
- Verify packages with the `mcp-nixos` MCP before adding; it tracks unstable and reports cache status

### Task Running
- **Always use `flake`** for project tasks - check `flake --list` first before running commands manually
- `flake` is a shell function: `just --justfile "$FLAKE/Justfile"`

### Markdown
- `marksman` is the language server; `markdownlint-cli2` exists but nothing in the repo runs it
