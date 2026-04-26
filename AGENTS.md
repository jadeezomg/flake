# Nix Flake Agent Guide

Essential knowledge for AI agents working in this NixOS/Darwin flake. Focuses on non-obvious patterns, gotchas, and efficient workflows.

## Core Philosophy

**Single-flake, multi-host** configuration managing three machines:

| Key | Hostname | System | Description |
|-----|----------|--------|-------------|
| `desktop` | `desktop-nixos` | x86_64-linux | NVIDIA desktop |
| `framework` | `framework-nixos` | x86_64-linux | Framework 13 7040 |
| `caya` | `caya-darwin` | aarch64-darwin | Apple Silicon |

Active host is determined by `.flake-host` (never commit it).

---

## Critical Rules (Non-Negotiable)

1. **Always use `just` recipes** — never run `nixos-rebuild`, `home-manager switch`, or bare `nh` directly
2. **Always verify packages** with `nix search nixpkgs` before adding anything
3. **Always format** with `just fmt` after editing any `.nix` file
4. **Never commit secrets** — use `sops` for encrypted secrets management
5. **Check Hydra** before adding packages (see below) to ensure binary cache availability

---

## Directory Structure

```
flake/
├── flake.nix                  # flake-parts entrypoint; perSystem packages defined here
├── Justfile                   # ALL build/switch/format commands
├── lib/
│   ├── pkgs.nix               # getPkgs / getPkgsStable helpers (allowUnfree + overlays)
│   └── packages/              # Shared package lists (minimal.nix, sandbox-floor.nix)
├── parts/
│   ├── hosts.nix              # Builds nixosConfigurations + darwinConfigurations
│   ├── shells.nix             # devShell
│   └── overlays/
│       ├── default.nix        # Central overlay list (local-packages + niri + cachyos kernel)
│       └── local-packages.nix # Auto-registers packages/* as pkgs.<name>
├── data/
│   ├── hosts/hosts.nix        # Host definitions (system, username, homeDirectory, monitors)
│   └── users/users.nix        # User definitions
├── hosts/                     # Host-specific configs (imports modules/shared + modules/nixos|darwin)
│   ├── desktop/               # Has gpu.nix, display.nix, hardware-configuration.nix
│   ├── framework/             # Has gpu.nix, input.nix, power.nix, hardware-configuration.nix
│   └── caya/                  # Darwin; wires nix-homebrew
├── modules/
│   ├── shared/                # Cross-platform system modules
│   │   ├── profiles/          # Profile options + implementations (see Profile System below)
│   │   ├── environment.nix
│   │   ├── fonts.nix
│   │   ├── security.nix
│   │   └── shells.nix
│   ├── nixos/                 # Linux-only system config (boot, hardware, networking, etc.)
│   │   └── profiles/          # Linux-specific profile implementations (desktop, integrations)
│   └── darwin/                # macOS system config + Homebrew wiring
├── home/
│   ├── shared/                # Cross-platform home-manager (apps, shells, development, assets)
│   ├── nixos/                 # Linux-only HM (desktop = niri + DMS config via symlinks)
│   └── darwin/                # macOS-only HM (brew casks)
├── packages/                  # Custom flake packages; auto-registered via overlay
│   └── <name>/
│       ├── default.nix
│       └── update.json        # Drives `just update-packages` / `just nix-update-pkg`
├── scripts/
│   ├── pyproject.toml         # uv/Hatch project `flake-scripts`
│   ├── shell/                 # Bash helpers (common.sh, just-choose.bash)
│   └── src/flake_scripts/     # Python package (check_packages, symlinks, update_packages, zen/)
└── secrets/secrets.yaml       # sops-encrypted secrets (age keys)
```

---

## Essential Commands

### Build & Switch
```bash
just switch          # flake check + nh switch (full path; also runs just git)
just switch-fast     # nh switch only (skip flake check; fastest iteration)
just build           # build without switching
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
just check-packages            # scan flake for broken/missing package refs
just nix-update-pkg            # bump one flake package (fzf picker or pass attr)
just update-packages [NAMES]   # run update.json handlers for custom packages
just update                    # full refresh: update-packages + flake.lock + fmt
UPDATE_FORCE=1 just update     # bypass per-package 1h cooldown
```

### Generations & GC
```bash
just generation-list           # list system generations
just generation-switch         # switch to a numbered generation
just rollback                  # roll back to previous generation
just gc-keep                   # nh clean keeping N generations (prompts)
just gc-days                   # nh clean keeping paths newer than N days
just gc-all                    # aggressive nh clean all + empty Trash
```

### Maintenance
```bash
just health                    # git status + disk usage + nh os info
just symlink-check             # DMS / niri / quickshell symlink report
just symlink-check-dms         # strict: DMS settings.json must symlink into flake
just reload-services           # reload niri, swaybg, waybar, mako (Linux)
just post-install              # install Context7 CLI skills after a fresh switch
just backups                   # list *.backup / *.bkp in ~/.config
just backups-clean             # delete those backup files
```

### Zen Browser Integration
```bash
just zen-sync                  # write spaces.nix + pins.nix from live session + fmt
just zen-compare               # diff flake vs live session (exit 0 = match)
just zen-extract [--nix]       # show pinned tabs per workspace
```

### Secrets
```bash
sops secrets/secrets.yaml      # decrypt → edit → re-encrypt on save
just setup-age-darwin          # bootstrap age key on new macOS machine
# After editing .sops.yaml recipients:
sops updatekeys secrets/secrets.yaml
```

### Hydra Build Status (Cache Check)
```bash
# Always check before adding a package — prevents cache misses
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/<name>.x86_64-linux/latest-finished" | jq '.success'
```

---

## Module System & Special Args

### Available in All Modules
```nix
{ pkgs, lib, config, inputs, hostData, hostKey, host, user, isDarwin, system, pkgs-stable }
```

- `hostKey` — `"desktop"`, `"framework"`, or `"caya"` (use this for host conditionals)
- `host` — full host record from `data/hosts/hosts.nix` (includes `mainMonitor.*`)
- `isDarwin` — `true` on macOS
- `pkgs-stable` — nixpkgs 25.11 (pinned stable channel)

### Common Patterns
```nix
# Host-conditional config
lib.mkIf (hostKey == "desktop") { ... }

# Platform-conditional list
lib.optionals (!isDarwin) [ pkgs.something ]

# Stylix theme colors (base16)
config.lib.stylix.colors.base0D   # blue accent

# Import from another flake input
imports = [ inputs.some-flake.homeModules.default ];

# Access host monitor info
host.mainMonitor.monitorID         # e.g. "DP-2"
host.mainMonitor.monitorScalingFactor
```

---

## Profile System

All profile toggles live in `modules/shared/profiles/default.nix`. Enable them per-host in `hosts/<name>/default.nix`:

```nix
dotfiles.profiles = {
  devenv.enable = true;          # enables all sub-profiles (tools, cloud, llm, languages...)
  apps.enable = true;            # enables browser, terminal, editor, etc. sub-profiles
  gaming.enable = true;          # Steam stack (Linux only)
  work.enable = true;            # Workato, Postman, browsers on Darwin
  desktop.enable = true;         # niri + DMS + GNOME fallback (Linux only; default: true)
  essentials.promptEngine = "starship";  # or "oh-my-posh"
};
```

**Important**: `devenv.enable = true` auto-enables all sub-profiles via `lib.mkDefault`. Override selectively:
```nix
dotfiles.profiles.devenv.llm.hosting.enable = false;   # disable vllm/lmstudio
dotfiles.profiles.devenv.languages.swift.enable = false;
```

Available language sub-profiles: `data`, `docs`, `general`, `nix`, `python`, `ruby`, `rust`, `shell`, `swift`, `web`.

---

## Where to Put Things

| What | Where |
|------|-------|
| System packages (all hosts) | `modules/shared/profiles/<profile>.nix` |
| System packages (all nixos) | `modules/nixos/profiles/<profile>.nix` |
| System packages (all darwin) | `modules/darwin/profiles/<profile>.nix` |
| System packages (one host only) | `hosts/<name>/default.nix` |
| User packages (cross-platform HM) | `home/shared/apps/` or `home/shared/development/` |
| User packages (Linux-only HM) | `home/nixos/` |
| User packages (macOS-only HM) | `home/darwin/` |
| NixOS services/daemons | `modules/nixos/` |
| Desktop/Wayland config | `modules/nixos/profiles/desktop.nix` or `home/nixos/desktop/` |
| Language tooling | `modules/shared/profiles/devenv/languages/<lang>.nix` |
| LLM agent tooling | `modules/shared/profiles/devenv/llm/agents.nix` |
| Theme/fonts | `home/shared/assets/` |
| Custom packages | `packages/<name>/default.nix` + `update.json` |
| macOS Homebrew casks/brews | `modules/darwin/default.nix` |

---

## Custom Packages (`packages/`)

All packages in `packages/*/default.nix` are auto-registered as `pkgs.<name>` via `parts/overlays/local-packages.nix`. Two calling conventions supported:
- `{ pkgs, lib, ... }:` → `pkgs = final` injected automatically
- `{ lib, rustPlatform, fetchFromGitHub, ... }:` → standard `callPackage` convention

Every updatable package has `update.json` with a `type`:
- `nix-update` — delegates to `nix-update --flake <attr>` (most packages)
- `npm` — npm registry packages (see `packages/context7/`)
- `github_npm` — GitHub releases + npm lock regeneration
- `binary_channel` — version URL + platform hash map 

`.update-check.json` stores last-checked timestamp; 1h cooldown by default. Skip with `UPDATE_FORCE=1`.

---

## Desktop Stack (Linux)

- **Compositor**: niri (niri-unstable from `niri-flake`; overlay applied x86_64-linux only)
- **Shell**: DankMaterialShell (DMS) via `inputs.dms`; config symlinked from `home/nixos/desktop/dms/config/`
- **Greeter**: DMS greeter (replaces GDM)
- **Fallback DE**: GNOME kept as session fallback
- **Kernel**: CachyOS Zen4 kernel on x86_64-linux (via `nix-cachyos-kernel` overlay); falls back to `linuxPackages_latest`
- **Secure Boot**: lanzaboote (`/var/lib/sbctl`); `systemd-boot` is force-disabled

### Niri Config Symlinks
`home/nixos/desktop/dms/default.nix` uses `mkOutOfStoreSymlink` to point config files at the live flake root — edits take effect without a `switch`. Key pattern:
- All DMS config files except `settings-*.json` are auto-symlinked
- `settings.json` → host-specific `settings-{framework,desktop}.json`
- `niri/host.kdl` → host-specific `outputs-{framework,desktop}.kdl`

After editing niri/DMS config files: `just reload-services` or `just symlink-check`.

---

## Theme

**Birds of Paradise** (dark brown/warm palette). Defined in `home/shared/assets/theme/theme.nix` — all color values live there; reference via Stylix base16 or import directly. The Python mirror lives at `scripts/src/flake_scripts/lib/palette.py` — keep both in sync when updating colors.

Stylix is enabled globally (`stylix.autoEnable = true`) but vscode, firefox, and niri targets are explicitly disabled. GTK gets custom CSS for 90% opacity.

---

## Secrets

- Encrypted with `sops` + `age`; keys in `~/.config/sops/age/keys.txt`
- All three hosts have age keys registered in `.sops.yaml`
- Secrets auto-export to interactive shells via `home/shared/shells/sops-shell-secrets.nix`:
  - Attr `foo-bar` → env var `FOO_BAR`
  - `github-token` → also sets `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `NIX_CONFIG` access-tokens

---

## Gotchas & Non-Obvious Patterns

### 1. `.flake-host` File
Created by `just init` (prompted) or `just _init <host>` (scripted). Never commit it. All `nh`-based recipes read it to determine which host to build.

### 2. Hostname ≠ Host Key
The `hostKey` (e.g. `"desktop"`) differs from `hostname` (e.g. `"desktop-nixos"`). Always use `hostKey` for Nix conditionals; `hostname` is the system hostname.

### 3. nixpkgs-zed Input
`nixpkgs-zed` is a pinned nixpkgs commit for a specific zed-editor version. It does **not** follow `nixpkgs`. Don't accidentally upgrade it when running `nix flake update`.

### 4. Local Packages Are pkgs.<name>
After adding `packages/<name>/default.nix`, the package is immediately available as `pkgs.<name>` everywhere — no explicit import needed. The overlay (`local-packages.nix`) handles it.

### 5. Conditional Imports Always Need a `default.nix` Entry
When creating a new `.nix` file in any directory, add it to that directory's `default.nix` imports list. Files not imported are silently ignored.

### 6. `pkgs-stable` for Specific Packages
Use `pkgs-stable.<pkg>` when a package needs pinned stability. It's nixpkgs 25.11 without overlays (no local packages, no niri/cachyos overlays).

### 7. `just switch` Runs `just git` First
The full `switch` recipe auto-runs `just git` (formats + prompts for commit). Use `just switch-fast` to skip this entirely.

### 8. `just update` Does Three Things
1. `update-packages` (custom package version + hash updates)
2. `nix flake update` (flake.lock)
3. `just fmt`

For framework host, also checks firmware via `fwupdmgr`.

### 9. Darwin: No nixpkgs Nix Daemon
`modules/darwin/default.nix` sets `nix.enable = false` — the Determinate Nix installer manages the daemon on macOS. Don't re-enable it.

### 10. Home-Manager Guest Users
`homeManagerConfig` in `parts/hosts.nix` also creates HM configs for `extraUsers` (currently `angelie`). Guest users share the same HM module set as the primary user.

### 11. `backupFileExtension = "backup"` + `overwriteBackup = true`
Home-manager is configured to overwrite backup files on conflict. Old `.backup` files accumulate; clean with `just backups-clean`.

### 12. DMS Settings Are Not Store-Copied
`settings.json` for DMS is a live symlink into the flake — changes to `home/nixos/desktop/dms/config/settings-*.json` apply immediately without a switch. Run `just symlink-check-dms` to verify the link is correct.

### 13. Lanzaboote Requires sbctl
Secure boot keys live at `/var/lib/sbctl`. On a fresh install, `sbctl` must be run before `lanzaboote` will work. Don't touch `boot.loader.systemd-boot.enable` — it's force-disabled.

### 14. Framework-Control Has Its Own nixpkgs
`inputs.framework-control` uses a bundled nixpkgs fork and does **not** follow the flake's `nixpkgs`. Its package is system-gated to `x86_64-linux` in `local-packages.nix`.

---

## Testing Your Changes

1. `just fmt` — format first
2. `just build-dry` — catch eval errors before committing
3. `just switch-fast` — fast iteration (no flake check)
4. `just switch` — full switch with flake check
5. `just symlink-check` — verify symlinks after desktop config changes
6. `just health` — post-switch system sanity check

---

## Debugging

| Problem | Command |
|---------|---------|
| Full eval trace | `just build-dev` |
| List generations | `just generation-list` |
| Symlink issues | `just symlink-check` |
| Broken package refs | `just check-packages` |
| Nix options reference | https://search.nixos.org/options |
| Home-manager options | https://home-manager-options.extendnix.com |

---

## Common Pitfalls

- **Never edit `.flake-host`** — it's generated per-machine
- **Never commit `.flake-host`** or `secrets.yaml` (unencrypted)
- **Always run `just fmt`** after editing `.nix` files
- **Never use `nixos-rebuild`** — use `just` recipes instead
- **Always verify packages** with `nix search` before adding
- **Don't assume binary cache** — check Hydra first
- **`stateVersion` is per-host** — never change it on existing hosts
