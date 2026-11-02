# Shell Aliases and Commands Reference

This document lists all aliases and commands available across different shells in this configuration.

---

## Tool replacements (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `cat` | `bat` | Better `cat` with syntax highlighting |
| `find` | `fd` | Faster `find` alternative |
| `grep` | `rg` | Ripgrep - faster `grep` alternative |
| `trash` | `gio trash` *(Linux only)* | Move files to trash via GLib. On Darwin, the `trash` Homebrew formula provides the binary directly (no alias). |

## Directory Listing (eza) (Bash, Nushell, Zsh)

Source: `modules/profiles/minimal/shells/core/data/aliases.nix` (same `shellAliases` map for every shell).

| Alias | Command | Description |
|-------|---------|-------------|
| `ll` | `eza --icons -l --git` | Git-aware list with icons |
| `l2` | `eza --icons -l -T -L=2` | List with tree view, depth 2 |
| `l3` | `eza --icons -l -T -L=3` | List with tree view, depth 3 |
| `llt` | `eza --icons -T` | Tree view (icons) |
| `lat` | `eza --icons -Ta` | Tree view (all files) |
| `tree` | `eza --icons -Ta` | Same as `lat` |
| `lat1` | `eza --icons -Ta -L=1` | Tree view, depth 1 |
| `lat2` | `eza --icons -Ta -L=2` | Tree view, depth 2 |
| `lat3` | `eza --icons -Ta -L=3` | Tree view, depth 3 |
| `lat4` | `eza --icons -Ta -L=4` | Tree view, depth 4 |
| `lat5` | `eza --icons -Ta -L=5` | Tree view, depth 5 |

## Navigation shortcuts (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `z ..` | Navigate up one directory |
| `...` | `z ../..` | Navigate up two directories |
| `....` | `z ../../..` | Navigate up three directories |
| `.....` | `z ../../../..` | Navigate up four directories |

## Editor shortcuts (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `zed` | `zeditor` | Open Zed editor |

## General shortcuts (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `cl` | `clear` | Clear terminal |
| `h` | `history` | Show command history |

## LLM shortcuts (Bash, Nushell, Zsh)

| Command | Implementation | Description |
|---------|----------------|-------------|
| `p <question...>` | `pi -p "<question...>"` | Non-interactive Pi prompt shortcut. Joins unquoted words into one prompt and preserves piped stdin, e.g. `just <recipe> | p what is this`. |

## Git shortcuts — basic (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `gst` | `git status` | Show git status |
| `gad` | `git add .` | Stage all changes |
| `gcm` | `git commit -m` | Commit with message |
| `gpu` | `git push -u origin main` | Push to main branch |

## Search shortcuts (Bash, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `search` | `rg --smart-case` | Smart case search |
| `searchf` | `fd --type f` | Find files |
| `searchd` | `fd --type d` | Find directories |

---

## Directory navigation (`zz` / `zc` / `zd`)

| Function | Description | Path |
|----------|-------------|------|
| `zz` | Navigate to home | `$HOME` |
| `zc` | Navigate to config | `$HOME/.config` |
| `zd` | Navigate to downloads | `$HOME/Downloads` |

Implemented per shell in `modules/profiles/minimal/shells/core/bash.nix`, `core/zsh.nix`, and `core/nushell.nix` (same behavior; Nushell uses `def --env`).

## Dotfiles & flake helpers (Bash, Nushell, Zsh)

All defined in `modules/profiles/essentials/shell-system-env.nix` (pushed by the essentials profile), together with `FLAKE`, `NH_FLAKE`, and workstation `PATH` bits.

| Function | Description |
|----------|-------------|
| `zf` | `cd` to `dotfiles.flakeRoot` (default `$HOME/git/flake`) |
| `flake` | `just --justfile $FLAKE/Justfile` with your arguments. No args → the `default` recipe, **`tv … just-recipes`** (cable in `modules/profiles/essentials/utils/television/cable/`). |

Requires **`just`** on PATH. **`FLAKE`** / **`NH_FLAKE`** follow **`dotfiles.flakeRoot`** (default `~/git/flake`).

`mini <cmd>` is a command on PATH, not a shell function. It runs the Justfile of the private mini-nix repo in `~/git/mini-nix`. Source: `modules/profiles/minimal/shells/mini-cli.nix`.

---

## Git shortcuts (Nushell only)

These are small functions in `modules/profiles/minimal/shells/core/nushell.nix`. Each one passes its arguments to git.

| Command | Runs | Description |
|---------|------|-------------|
| `gs` | `git status` | Show git status |
| `gl` | `git log --oneline --decorate --graph` | Compact log graph |
| `gb` | `git branch` | Branch operations |
| `gp` | `git push` | Push |
| `ga` | `git add` | Stage files |
| `gc` | `git commit -v` | Commit, with the diff in the editor |
| `gd` | `git diff` | Show differences |
| `gm` | `git merge` | Merge branches |
| `gr` | `git remote` (`git remote -v` with no arguments) | Manage remotes |

---

## Notes

- **Shared aliases** (`cat`, `find`, `grep`, `ll`, eza shortcuts, git one-liners, `search*`, etc.) live in `modules/profiles/minimal/shells/core/data/aliases.nix` and are wired as `shellAliases` from `modules/profiles/minimal/shells/core/{bash,zsh,nushell}.nix`.
- **`zz` / `zc` / `zd`** and **`p`** are small functions in those same `core/*.nix` files (not separate alias modules). `p <question...>` wraps `pi -p "<question...>"` while preserving piped stdin.
- **`zf` / `flake`** and workstation env (`FLAKE`, extra `PATH`) come from `modules/profiles/essentials/shell-system-env.nix`.
- **Navi cheat** for quick lookup: `modules/profiles/essentials/utils/navi/cheats/aliases.cheat` (points at the paths above).
- **Nushell git functions** (`gs`, `gl`, `gb`, …) are defined in `modules/profiles/minimal/shells/core/nushell.nix`. **Nushell only.**

---

## Quick Reference by Category

### Most Used Commands

**Navigation:**
- `zz`, `zc`, `zd`, `zf` - Quick directory navigation
- `..`, `...`, `....`, `.....` - Navigate up directories

**Git (Nushell only):**
- `gl` - View log
- `gb` - Branch operations
- `ga` - Stage files
- `gc` - Commit
- `gp` - Push
- `gd` - View diff

**System:**
- `flake` - Run a flake recipe (`tv` chooser when no args)
- `cl` - Clear terminal
- `p <question...>` - Ask Pi a one-shot question, including piped stdin

**File Operations:**
- `cat` - View files (bat)
- `search` - Search files (ripgrep)
- `searchf` - Find files (fd)
- `searchd` - Find directories (fd)

