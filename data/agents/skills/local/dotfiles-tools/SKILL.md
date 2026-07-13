---
name: dotfiles-tools
description: Reference for all CLI tools and development preferences in jadee's dotfiles flake. Use this skill whenever helping with shell tasks, writing scripts, recommending tools, or answering "what tool should I use for X". Covers NixOS (desktop/framework) and macOS (caya). Always prefer the tools and methods here over generic alternatives. Trigger when the user is working in a terminal, asking about file operations, text processing, git, development workflows, or system administration.
---

# Dotfiles CLI Tools & Development Preferences

**Edit this skill in the flake only:** `data/agents/skills/local/dotfiles-tools/` (including `references/`). Do not edit `~/.agents/skills/dotfiles-tools/` — Home Manager copies from the flake on `flake switch`.

For platform-specific tools, read `references/nixos.md` (NixOS) or `references/darwin.md` (macOS).
The full shared tool list is in `references/shared-tools.md`.

## Preferred Development Methods

### Python
- **Always use `uv`** - never `pip`, `pip3`, or `poetry`
- `uv add <pkg>` to add dependencies, `uv run <script>` to run, `uv sync` to install
- `ruff` for linting and formatting (not black/flake8), `ty` for type checking

### JavaScript / TypeScript
- **Always use `yarn`** - never `npm` or `pnpm`
- `yarn add <pkg>`, `yarn dev`, `yarn build`
- `biome` for linting and formatting (not eslint/prettier for JS/TS projects)
- `bun` for scripts/running when speed matters, but yarn for package management

### Rust
- `cargo` for all package management and builds
- `bacon` for background compile-on-save watching during development
- `rustup` to manage toolchain versions

### Nix
- Format with `flake fmt` (runs nixfmt-tree/treefmt), never edit unformatted
- Use `flake switch` / `flake switch-fast` - never bare `nixos-rebuild`, `darwin-rebuild`, or `nh`
- Verify packages with `nix search nixpkgs <name>` before adding

### Task Running
- **Always use `flake`** for project tasks - check `flake --list` first before running commands manually

## File Deletion

- **Never use `rm` or `rmdir`** — use trash instead
- **Interactive shell:** `trash <path>` (user alias)
- **Under `sudo`:** use `gio trash` — the `trash` alias is not available in sudo's environment

```bash
trash ./some-file
sudo gio trash /path/owned/by/root
```

## Shell Functions

- `z <dir>` - smart directory jump (zoxide)
- `flake <cmd>` - shorthand for `flake` recipes
