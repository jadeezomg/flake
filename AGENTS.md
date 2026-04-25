# Nix Flake Agent Guide

This guide contains essential knowledge for AI agents working in this NixOS flake. Focus on non-obvious patterns, gotchas, and efficient workflows.

## Core Philosophy

This is a **single-flake, multi-host** configuration managing three machines:
- `desktop`: x86_64-linux (NVIDIA)
- `framework`: x86_64-linux (Framework 13 7040)
- `caya`: aarch64-darwin (Apple Silicon)

All changes flow from a shared set of modules. The active host is determined by `.flake-host`.

## Critical Rules (Non-Negotiable)

1. **Always use `just` recipes** - never run `nixos-rebuild`, `home-manager switch`, or bare `nh` commands
2. **Always verify packages/attributes** with `nix search nixpkgs` before adding anything
3. **Always format** with `just fmt` after editing any `.nix` file
4. **Never commit secrets** - use `sops` for encrypted secrets management

## Directory Structure Quick Reference

```
flake/
├── flake.nix              # flake-parts entrypoint
├── Justfile               # ALL build/switch/format commands
├── lib/pkgs.nix           # getPkgs / getPkgsStable helpers
├── parts/hosts.nix        # builds nixosConfigurations + darwinConfigurations
├── data/
│   ├── hosts/hosts.nix    # host definitions (system, username, homeDirectory)
│   └── users/users.nix    # user definitions
├── hosts/                 # host-specific configs
│   ├── desktop/
│   ├── framework/
│   └── caya/
├── modules/               # shared system modules
│   ├hared/            # cross-platform ── shared/            # cross-platform
│   ├── nixos/             # Linux-only
│   └── darwin/            # macOS-only
├── home/                  # home-manager config
│   ├── shared/            # cross-platform
│   ├── nixos/             # Linux-only
│   └── darwin/            # macOS-only
├── packages/              # custom flake packages
└── scripts/               # Python console scripts + shell helpers
```

## Essential Commands

### Build & Switch
```bash
just switch          # full flake check + nh switch
just switch-fast     # nh switch only (skip flake check)
just build-dry       # dry run evaluation
just rollback        # revert to previous generation
```

### Format & Lint
```bash
just fmt             # alejandra + deadnix + ruff + ty + biome
just lint            # deadnix + statix (linting)
```

### Maintenance
```bash
just update          # refresh externals: packages, flake.lock, fmt
just health          # git status, disk usage, system info
just gc-days         # clean store paths older than N days
```

### Package Management
```bash
nix search nixpkgs <name>   # verify package/attribute exists
just check-packages    # scan flake for broken package refs
just nix-update-pkg   # bump one flake package (interactive picker)
```

### Hydra Build Status (Cache Check)
```bash
# Check if package is built and cached
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/<name>.x86_64-linux/latest-finished" | jq '.success'

# Get store path for verification
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/<name>.x86_64-linux/latest-finished" | jq -r '.buildoutputs.out.path'
```

## Module System Patterns

### Special Args Available in All Modules
```nix
{ pkgs, lib, config, inputs, hostData, hostKey, host, user, isDarwin, system, pkgs-stable }:
```

### Common Patterns
```nix
# Conditional on host
lib.mkIf (hostKey == "desktop") { ... }

# Conditional list
lib.optionals (!isDarwin) [ pkgs.something ]

# Stylix color
config.lib.stylix.colors.base0D

# Import from another flake
imports = [ inputs.some-flake.homeModules.default ];
```

## Where to Put Things

### System Packages
- **All Linux hosts**: `modules/shared/` (appropriate category)
- **One host only**: `hosts/<name>/default.nix`

### User Packages (home-manager)
- **Cross-platform**: `home/shared/apps/`
- **Linux-only**: `home/nixos/`
- **macOS-only**: `home/darwin/`

### NixOS Services/Daemons
- `modules/nixos/services/`

### Desktop/Wayland Config
- `modules/nixos/desktop/` or `home/nixos/desktop/`

### Language Dev Config
- `home/shared/development/languages/<lang>.nix`

### Theme/Fonts/Symlinks
- `home/shared/assets/`

### Custom Packages
- `packages/<name>/default.nix`
- Add to `parts/overlays/` if you need custom nixpkgs overlays

## Gotchas & Non-Obvious Patterns

### 1. The `.flake-host` File
- Determines active host for all `nh`-based commands
- Created by `just init` (prompts) or `just _init <host>` (no prompt)
- **Never commit this file** - it's host-specific

### 2. Python Scripts Are a First-Class Citizen
The `scripts/` directory is a `uv`-managed Python package with console entry points:
```bash
uv run --project scripts <command>
```
Common commands:
- `symlink-check` - verify DMS/niri/quickshell symlinks
- `check-packages` - scan for broken package references
- `update-packages` - bump custom flake packages
- `zen-session` - browser session sync/extract

### 3. Justfile Groups
Recipes are organized in groups. Use `just --list` to see all recipes in order.
- `build` - system builds
- `switch` - system switches  
- `generations` - generation management
- `gc` - garbage collection
- `format` - formatting/linting
- `check` - validation checks
- `config` - configuration setup
- `system` - system maintenance
- `repo` - git operations
- `zen` - Zen browser integration

### 4. Conditional Imports
When creating a new `.nix` file, **always add an import to that directory's `default.nix`**:
```nix
# In modules/shared/default.nix or similar
imports = [ ./my-new-file.nix ];
```

### 5. The `specialArgs` Pattern
The flake passes rich context to every module. Use these instead of hardcoding:
- `hostKey` - current host name (`"desktop"`, `"framework"`, `"caya"`)
- `isDarwin` - true on macOS
- `pkgs-stable` - stable nixpkgs set

### 6. Secrets Management
- Edit with `sops secrets/secrets.yaml` (decrypts on open, re-encrypts on save)
- Age keys: `~/.config/sops/age/keys.txt`
- Darwin bootstrap: `just setup-age-darwin`
- Secrets auto-export to interactive shells via `home/shared/shells/sops-shell-secrets.nix`

### 7. Hydra Build Status is Required
**Always** check if a package is built and cached before adding it. This prevents CI failures and ensures binary cache availability.

### 8. The `update` Recipe Does Three Things
```bash
just update
# 1. update-packages (packages/*/update.json, nix-update entries)
# 2. nix flake update (flake.lock)
# 3. just fmt (format all .nix files)
```

### 9. Framework-Specific Maintenance
The `just update` recipe also checks for Framework BIOS/firmware updates via `fwupdmgr` when on the framework host.

### 10. Symlink Validation
After making changes that affect symlinks (DMS settings, niri, quickshell), run:
```bash
just symlink-check   # general report
just symlink-check-dms  # strict DMS settings check
```

## Testing Your Changes

1. **Format first**: `just fmt`
2. **Dry run**: `just build-dry`
3. **Switch**: `just switch` (or `just switch-fast` for quick iteration)
4. **Verify**: Check for errors, then `just health` for system status

## Debugging

- **Show trace**: `just build-dev` or `just switch-dev` for full evaluation trace
- **Check generations**: `just generation-list`
- **System info**: `just health`
- **NixOS options**: Search online at https://search.nixos.org/options

## Common Pitfalls

- **Never edit `.flake-host`** - it's generated
- **Never commit `.flake-host`** or `secrets.yaml` (unencrypted)
- **Always run `just fmt`** after editing `.nix` files
- **Never use `nixos-rebuild`** - use `just` recipes instead
- **Always verify packages** with `nix search` before adding
- **Don't assume binary cache availability** - check Hydra first

## When You're Stuck

1. Check the existing documentation in `README.md` and `Justfile`
2. Look at similar modules for patterns
3. Use `nix search nixpkgs` for package verification
4. Run `just build-dry` for evaluation errors
5. Ask for help with specific error messages

## Next Steps for New Agents

1. Read `README.md` for high-level overview
2. Study `Justfile` to understand available commands
3. Explore `modules/shared/default.nix` to see the import pattern
4. Try making a small change and going through the workflow
5. Get comfortable with `nix search` and Hydra API
