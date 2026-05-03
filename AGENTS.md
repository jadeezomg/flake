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

1. **Always use `just` recipes** — never run `nixos-rebuild`, `home-manager switch`, or bare `nh` directly
2. **Always verify packages** with `nix search nixpkgs` before adding anything
3. **Always format** with `just fmt` after editing any `.nix` file
4. **Run `git add`** before `nix eval/build` (flakes only see tracked files)
5. **Never commit secrets** — use `sops` for encrypted secrets management
6. **Check Hydra** before adding packages to ensure binary cache availability

---

## Essential Commands

### Build & Switch
```bash
just build-dry       # dry-run eval/build (no switch); use to catch errors
just build-dev       # build with --show-trace (full evaluation trace)
just switch-check    # run nix flake check only (no switch)
```

### Format & Lint
```bash
just fmt             # alejandra (.nix) + deadnix + ruff (scripts) + ty (type-check) + biome (js/ts/json)
just lint            # deadnix + statix antipattern checks
```

### Package Management
```bash
nix search nixpkgs <name>      # ALWAYS verify before adding a package
just update-packages [NAMES]   # run update.json handlers for custom packages
just update                    # full refresh: update-packages + flake.lock + fmt
UPDATE_FORCE=1 just update     # bypass per-package 1h cooldown
```

### Generations
```bash
just generation-list           # list system generations
just generation-switch         # switch to a numbered generation
just rollback                  # roll back to previous generation
```

### Maintenance
```bash
just health                    # git status + disk usage + nh os info
just symlink-check             # DMS / niri / quickshell symlink report
just post-install              # install Context7 CLI skills after a fresh switch
just backups-clean             # delete *.backup / *.bkp in ~/.config
```

---

## Debugging

| Problem | Command |
|---------|---------|
| Full eval trace | `just build-dev` |
| List generations | `just generation-list` |
| Symlink issues | `just symlink-check` |
| Eval / missing attrs | `just build-dry` or `just switch-check` |
| Nix options reference | https://search.nixos.org/options |
| Home-manager options | https://home-manager-options.extendnix.com |
