# Shell Aliases and Commands Reference

This document lists all aliases and commands available across different shells in this configuration.

---

## Tool replacements (Bash, Fish, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `cat` | `bat` | Better `cat` with syntax highlighting |
| `find` | `fd` | Faster `find` alternative |
| `grep` | `rg` | Ripgrep - faster `grep` alternative |
| `trash` | `gio trash` *(Linux only)* | Move files to trash via GLib. On Darwin, the `trash` Homebrew formula provides the binary directly (no alias). |

## Directory Listing (eza) (Bash, Fish, Nushell, Zsh)

Source: `modules/profiles/minimal/shells/core/data/aliases.nix` (same `shellAliases` map for every shell).

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza --icons -l --git` | Git-aware list with icons |
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

## Navigation shortcuts (Bash, Fish, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `z ..` | Navigate up one directory |
| `...` | `z ../..` | Navigate up two directories |
| `....` | `z ../../..` | Navigate up three directories |
| `.....` | `z ../../../..` | Navigate up four directories |

## Editor shortcuts (Bash, Fish, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `zed` | `zeditor` | Open Zed editor |
| `code` | `cursor` | Open Cursor editor |

## General shortcuts (Bash, Fish, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `cl` | `clear` | Clear terminal |
| `h` | `history` | Show command history |

## LLM shortcuts (Bash, Fish, Nushell, Zsh)

| Command | Implementation | Description |
|---------|----------------|-------------|
| `p <question...>` | `pi -p "<question...>"` | Non-interactive Pi prompt shortcut. Joins unquoted words into one prompt and preserves piped stdin, e.g. `just <recipe> | p what is this`. |

## Git shortcuts — basic (Bash, Fish, Nushell, Zsh)

| Alias | Command | Description |
|-------|---------|-------------|
| `gst` | `git status` | Show git status |
| `gad` | `git add .` | Stage all changes |
| `gcm` | `git commit -m` | Commit with message |
| `gpu` | `git push -u origin main` | Push to main branch |

## Search shortcuts (Bash, Fish, Nushell, Zsh)

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

Implemented per shell in `modules/profiles/minimal/shells/core/bash.nix`, `core/fish.nix`, `core/zsh.nix`, and `core/nushell.nix` (same behavior; Nushell uses `def --env`).

## Dotfiles & flake helpers (Bash, Fish, Nushell, Zsh)

All defined in `modules/profiles/essentials/shell-system-env.nix` (pushed by the essentials profile), together with `FLAKE`, `NH_FLAKE`, and workstation `PATH` bits. Intended to apply when the **essentials** system profile is enabled; see the `lib.mkIf` in that file for the exact condition.

| Function | Description |
|----------|-------------|
| `zf` | `cd` to `dotfiles.flakeRoot` (default `$HOME/.dotfiles/flake`) |
| `flake` | `just --justfile $FLAKE/Justfile` — no args → **`tv … just-recipes`** (cable in `modules/profiles/essentials/utils/television/cable/`). With extra args on `build`/`switch`/`generation`/`gc`/`fmt`/`backups`/`init`/`read-defaults`, forwards to private `_…` recipes, e.g. `flake build --dry`, `flake init myhost`. |
| `nuflake` | `nu $FLAKE/build/flake.nu` |

Requires **`just`** on PATH. **`FLAKE`** / **`NH_FLAKE`** follow **`dotfiles.flakeRoot`** (default `~/.dotfiles/flake`).

---

## Git.nu Workflow Commands (Nushell Only)

These commands are provided by [git.nu](https://github.com/fj0r/git.nu) and are **only available in Nushell**.

### Core Git Commands (Nushell)

| Command | Function | Description |
|---------|----------|-------------|
| `gl` | `git-log` | View git log |
| `gst` | `git-stash` | Git stash operations |
| `gb` | `git-branch` | Branch operations |
| `gn` | `git-new` | Create new repository |
| `gig` | `git-ignore` | Manage .gitignore |
| `gp` | `git-pull-push` | Pull and push |
| `ga` | `git-add` | Stage files |
| `gdel` | `git-delete` | Delete files from git |
| `gc` | `git-commit` | Commit changes |
| `gd` | `git-diff` | Show differences |
| `gm` | `git-merge` | Merge branches |
| `gr` | `git-rebase` | Rebase branches |
| `gcp` | `git-cherry-pick` | Cherry-pick commits |
| `gcpf` | `git-copy-file` | Copy file from another branch |
| `grs` | `git-reset` | Reset changes |
| `grm` | `git-remote` | Manage remotes |
| `gbs` | `git-bisect` | Binary search for bugs |
| `ggc` | `git-garbage-collect` | Clean up repository |
| `ghm` | `git-histogram-merger` | Histogram merger |
| `gha` | `git-histogram-activities` | Histogram activities |

### Git Config & Switching (Nushell)

| Command | Function | Description |
|---------|----------|-------------|
| `gcl` | `git config --list` | List git config |
| `gsw` | `git switch` | Switch branches |
| `gswc` | `git switch -c` | Create and switch branch |
| `gts` | `git tag -s` | Create signed tag |

### GitFlow Commands (Nushell)

| Command | Function | Description |
|---------|----------|-------------|
| `gfof` | `gitflow-open-feature` | Open feature branch |
| `gfcf` | `gitflow-close-feature` | Close feature branch |
| `gfrf` | `gitflow-resolve-feature` | Resolve feature |
| `gfrl` | `gitflow-release` | Release operations |
| `gfoh` | `gitflow-open-hotfix` | Open hotfix branch |
| `gfch` | `gitflow-close-hotfix` | Close hotfix branch |

### GitLab Commands (Nushell)

| Command | Function | Description |
|---------|----------|-------------|
| `gof` | `gitlab-open-feature` | Open GitLab feature |
| `gcf` | `gitlab-close-feature` | Close GitLab feature |
| `grf` | `gitlab-resolve-feature` | Resolve GitLab feature |
| `grl` | `gitlab-release` | GitLab release |
| `goh` | `gitflow-open-hotfix` | Open hotfix (GitLab) |
| `gch` | `gitflow-close-hotfix` | Close hotfix (GitLab) |

---

## Notes

- **Shared aliases** (`cat`, `find`, `grep`, `ls`, eza shortcuts, git one-liners, `search*`, etc.) live in `modules/profiles/minimal/shells/core/data/aliases.nix` and are wired as `shellAliases` from `modules/profiles/minimal/shells/core/{bash,fish,zsh,nushell}.nix`.
- **`zz` / `zc` / `zd`** and **`p`** are small functions in those same `core/*.nix` files (not separate alias modules). `p <question...>` wraps `pi -p "<question...>"` while preserving piped stdin.
- **`zf` / `flake` / `nuflake`** and workstation env (`FLAKE`, extra `PATH`) come from `modules/profiles/essentials/shell-system-env.nix`.
- **Navi cheat** for quick lookup: `modules/profiles/essentials/utils/navi/cheats/aliases.cheat` (points at the paths above).
- **git.nu** commands are loaded in `modules/profiles/minimal/shells/core/nushell.nix` from the upstream `git.nu` flake input fetch; **Nushell only**. Some names overlap bash-style `gst` / `gad` aliases but implement different flows — see [git.nu](https://github.com/fj0r/git.nu).

---

## Quick Reference by Category

### Most Used Commands

**Navigation:**
- `zz`, `zc`, `zd`, `zf` - Quick directory navigation
- `..`, `...`, `....`, `.....` - Navigate up directories

**Git - git.nu (Nushell only):**
- `gl` - View log
- `gb` - Branch operations
- `ga` - Stage files
- `gc` - Commit
- `gp` - Pull/push
- `gd` - View diff

**System:**
- `flake` / `nuflake` - Flake (`tv`/`fzf` chooser when no args) vs legacy Nu
- `cl` - Clear terminal
- `p <question...>` - Ask Pi a one-shot question, including piped stdin

**File Operations:**
- `cat` - View files (bat)
- `search` - Search files (ripgrep)
- `searchf` - Find files (fd)
- `searchd` - Find directories (fd)

