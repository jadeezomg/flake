# Shell Aliases and Commands Reference

This document lists all aliases and commands available across different shells in this configuration.

---

## Tool Replacements (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `cat` | `bat` | Better `cat` with syntax highlighting |
| `find` | `fd` | Faster `find` alternative |
| `grep` | `rg` | Ripgrep - faster `grep` alternative |

## Directory Listing (eza) (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `l2` | `eza --icons -l -T -L=2` | List with tree view, depth 2 |
| `l3` | `eza --icons -l -T -L=3` | List with tree view, depth 3 |
| `llt` | `eza -T` | Tree view |
| `lat` | `eza -Ta` | Tree view (all files) |
| `tree` | `eza -Ta` | Tree view (all files) |
| `lat1` | `eza -Ta -L=1` | Tree view, depth 1 |
| `lat2` | `eza -Ta -L=2` | Tree view, depth 2 |
| `lat3` | `eza -Ta -L=3` | Tree view, depth 3 |
| `lat4` | `eza -Ta -L=4` | Tree view, depth 4 |
| `lat5` | `eza -Ta -L=5` | Tree view, depth 5 |

## Navigation Shortcuts (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `z ..` | Navigate up one directory |
| `...` | `z ../..` | Navigate up two directories |
| `....` | `z ../../..` | Navigate up three directories |
| `.....` | `z ../../../..` | Navigate up four directories |

## Editor Shortcuts (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `zed` | `zeditor` | Open Zed editor |
| `code` | `cursor` | Open Cursor editor |

## General Shortcuts (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `cl` | `clear` | Clear terminal |
| `h` | `history` | Show command history |

## Git Shortcuts - Basic (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `gst` | `git status` | Show git status |
| `gad` | `git add .` | Stage all changes |
| `gcm` | `git commit -m` | Commit with message |
| `gpu` | `git push -u origin main` | Push to main branch |

## Search Shortcuts (Bash, Fish, Nushell)

| Alias | Command | Description |
|-------|---------|-------------|
| `search` | `rg --smart-case` | Smart case search |
| `searchf` | `fd --type f` | Find files |
| `searchd` | `fd --type d` | Find directories |

---

## Directory Navigation Functions (Bash, Fish, Nushell)

| Function | Description | Path |
|----------|-------------|------|
| `zz` | Navigate to home directory | `$HOME` |
| `zc` | Navigate to config directory | `$HOME/.config` |
| `zd` | Navigate to downloads directory | `$HOME/Downloads` |
| `zp` | Navigate to dotfiles directory | `$HOME/.dotfiles` |
| `zf` | Navigate to flake directory | `$HOME/.dotfiles/flake` |

## Home Manager Shortcuts (Bash, Fish, Nushell)

| Function | Description |
|----------|-------------|
| `hm` | Run home-manager command |
| `hms` | Apply home-manager configuration (switch) |
| `hmn` | Show home-manager news |

## Flake Management (Bash, Fish, Nushell)

| Function | Description |
|----------|-------------|
| `flake` | Run flake build script |

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

- **Common aliases** are defined in `home/shared/shells/shared/aliases.nix`
- **Shell-specific functions** are implemented in:
  - Bash: `home/shared/shells/bash/aliases.nix`
  - Fish: `home/shared/shells/fish/aliases.nix`
  - Nushell: `home/shared/shells/nushell/aliases.nix`
- **git.nu commands** are sourced from the [fj0r/git.nu](https://github.com/fj0r/git.nu) repository and are only available in Nushell
- Some git.nu commands may have different behavior than standard git commands - refer to the [git.nu documentation](https://github.com/fj0r/git.nu) for details

---

## Quick Reference by Category

### Most Used Commands

**Navigation:**
- `zz`, `zc`, `zd`, `zp`, `zf` - Quick directory navigation
- `..`, `...`, `....`, `.....` - Navigate up directories

**Git - git.nu (Nushell only):**
- `gl` - View log
- `gb` - Branch operations
- `ga` - Stage files
- `gc` - Commit
- `gp` - Pull/push
- `gd` - View diff

**System:**
- `hms` - Apply Home Manager config
- `flake` - Run flake scripts
- `cl` - Clear terminal

**File Operations:**
- `cat` - View files (bat)
- `search` - Search files (ripgrep)
- `searchf` - Find files (fd)
- `searchd` - Find directories (fd)

