# PROJECT KNOWLEDGE BASE

Essential knowledge for AI agents working in this NixOS/Darwin flake.

## Core Philosophy

**Single-flake, multi-host** configuration managing three machines:

| Key / Hostname | System | Description |
|----------------|--------|-------------|
| `desktop` | x86_64-linux | NVIDIA desktop |
| `framework` | x86_64-linux | Framework 13 7040 |
| `caya` | aarch64-darwin | Apple Silicon |

Active host is determined by `.flake-host` (never commit it).

---

## Critical Rules (Non-Negotiable)

1. **Always use `flake` recipes** — never run `nixos-rebuild`, `home-manager switch`, or bare `nh` directly
2. **Always verify packages** with `nix search nixpkgs` before adding anything
3. **Always format** with `flake fmt` after editing any `.nix` file
4. **Run `git add`** before `nix eval/build` (flakes only see tracked files)
5. **Never commit secrets** — use `sops` for encrypted secrets management
6. **Check Hydra** before adding packages to ensure binary cache availability
7. **Agent/skills files** — edit under `data/agents/` in this flake only; never `~/.claude/skills/`, `~/AGENTS.md`, or other installed copies (see `data/agents/skills/AGENTS.md`)

---

## Essential Commands

### Build & Switch
```bash
flake build-dry       # dry-run eval/build (no switch); use to catch errors
flake build-dev       # build with --show-trace (full evaluation trace)
flake switch-check    # run nix flake check only (no switch)
```

### Format & Lint
```bash
flake fmt             # alejandra (.nix) + deadnix + ruff (scripts) + ty (type-check) + biome (js/ts/json)
flake lint            # deadnix + statix antipattern checks
```

### Package Management
```bash
nix search nixpkgs <name>      # ALWAYS verify before adding a package
flake update-packages [NAMES]   # run update.json handlers for custom packages
flake update                    # full refresh: update-packages + flake.lock + fmt
UPDATE_FORCE=1 flake update     # bypass per-package 1h cooldown
```

### Generations
```bash
flake generation-list           # list system generations
flake generation-switch         # switch to a numbered generation
flake rollback                  # roll back to previous generation
```

### Maintenance
```bash
flake health                    # git status + disk usage + nh os info
flake symlink-check             # DMS / niri / quickshell symlink report
flake post-install              # install Context7 CLI skills after a fresh switch
flake backups-clean             # delete *.backup / *.bkp in ~/.config
```

---

## Debugging

| Problem | Command |
|---------|---------|
| Full eval trace | `flake build-dev` |
| List generations | `flake generation-list` |
| Symlink issues | `flake symlink-check` |
| Eval / missing attrs | `flake build-dry` or `flake switch-check` |
| Nix options reference | https://search.nixos.org/options |
| Home-manager options | https://home-manager-options.extendnix.com |
