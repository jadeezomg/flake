---
name: dotfiles-tools
description: Reference for all CLI tools and development preferences in jadee's dotfiles flake. Use this skill whenever helping with shell tasks, writing scripts, recommending tools, or answering "what tool should I use for X". Covers NixOS (desktop/framework) and macOS (caya). Always prefer the tools and methods here over generic alternatives. Trigger when the user is working in a terminal, asking about file operations, text processing, git, development workflows, or system administration.
---

# Dotfiles CLI Tools & Development Preferences

For platform-specific tools, read `references/nixos.md` (NixOS) or `references/darwin.md` (macOS).
The full shared tool list is in `references/shared-tools.md`.

## Preferred Tools by Task

| Task | Use | Not |
|------|-----|-----|
| View files | `bat` | `cat` |
| Find files | `fd` | `find` |
| Search content | `rg` | `grep` |
| List files | `eza -l --icons --git` | `ls` |
| Tree view | `eza -Ta` | `tree` |
| Navigate dirs | `z <dir>` (zoxide) | `cd` |
| Disk usage | `dust` or `dua` | `du` |
| Process monitor | `btop` | `top`/`htop` |
| JSON | `jq` | — |
| YAML/TOML/XML | `yq` | — |
| HTTP requests | `xh` | `curl`/`httpie` |
| Ping | `gping` | `ping` |
| Benchmark | `hyperfine` | `time` |
| Diagram | mermaid (inline in markdown) | — |
| Git TUI | `lazygit` | — |
| DB TUI | `rainfrog` | — |
| PDF tools | `pdftotext`, `qpdf`, `pdftk` | — |

## Preferred Development Methods

### Python
- **Always use `uv`** — never `pip`, `pip3`, or `poetry`
- `uv add <pkg>` to add dependencies, `uv run <script>` to run, `uv sync` to install
- `ruff` for linting and formatting (not black/flake8), `ty` for type checking

### JavaScript / TypeScript
- **Always use `yarn`** — never `npm` or `pnpm`
- `yarn add <pkg>`, `yarn dev`, `yarn build`
- `biome` for linting and formatting (not eslint/prettier for JS/TS projects)
- `bun` for scripts/running when speed matters, but yarn for package management

### Rust
- `cargo` for all package management and builds
- `bacon` for background compile-on-save watching during development
- `rustup` to manage toolchain versions

### Nix
- Format with `just fmt` (runs alejandra), never edit unformatted
- Use `just switch` / `just switch-fast` — never bare `nixos-rebuild`, `darwin-rebuild`, or `nh`
- Verify packages with `nix search nixpkgs <name>` before adding

### Shell Scripts
- `shellcheck` to lint, `shfmt` to format
- Prefer nushell scripts over bash for new work

### Task Running
- **Always use `just`** for project tasks — check `just --list` first before running commands manually

## Shell Functions

- `z <dir>` — smart directory jump (zoxide)
- `zf` — jump to flake root
- `flake <cmd>` — shorthand for `just` recipes
- `f` — pay-respects (suggests corrections for failed commands)

## Nushell git.nu shortcuts

`gs`, `gl`, `gb`, `gp`, `ga`, `gc`, `gd`, `gm`, `gr` (from fj0r/git.nu)
