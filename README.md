# dotfiles

jadee's NixOS + nix-darwin flake. Manages three machines from a single
`flake-parts` entrypoint with shared home-manager config across Linux and macOS.

- **flake.nix** — inputs, per-system outputs, `formatter = alejandra`
- **parts/hosts.nix** — builds `nixosConfigurations` and `darwinConfigurations`
  from `data/hosts/hosts.nix`
- **Justfile** — all day-to-day recipes (build, switch, gc, format, repo, zen...)

## Hosts

| Host | System | Hardware | Notes |
|---|---|---|---|
| `desktop` | `x86_64-linux` | NVIDIA GPU | `DP-2` @ 2560x1440 / 170Hz |
| `framework` | `x86_64-linux` | AMD, Framework 13 7040 | `eDP-2` @ 2880x1920 / 120Hz, 2.0x scale |
| `caya` | `aarch64-darwin` | Apple Silicon | user `caya-jonas`; `nix-homebrew` for casks |

Host definitions live in `data/hosts/hosts.nix` (hostname, system, username,
home directory, main monitor). Users live in `data/users/users.nix`. NixOS
hosts share `sharedNixOSUser = jadee` and an extra `angelie` account.

The active host is set in `.flake-host`. Change with `just init` (prompts) or
`just _init <host>` (no prompt).

## Quick start

```bash
# build / switch
just switch          # flake check + nh switch
just switch-fast     # nh switch only
just switch-check    # nix flake check only
just build-dry       # dry run
just build-dev       # switch with --show-trace
just rollback        # previous generation

# format / lint
just fmt             # alejandra + deadnix + ruff + ty + biome
just lint            # deadnix + statix

# maintenance
just update          # packages/*/update.json (incl. nix-update entries), flake.lock, fmt, Framework BIOS check
just gc-days         # nh clean, keep store paths newer than N days
just health          # git status, disk, nh os info
```

`just` alone launches an `fzf` picker over every recipe (see
`scripts/shell/just-choose.bash`).

## Justfile groups

| Group | Recipes |
|---|---|
| `build` | `build`, `build-boot`, `build-dev`, `build-dry` |
| `switch` | `switch`, `switch-fast`, `switch-check` |
| `generations` | `generation-list`, `generation-switch`, `generation-delete`, `generation-bootloader` |
| `gc` | `gc-keep`, `gc-days`, `gc-all` |
| `format` | `fmt`, `fmt-notree`, `lint` |
| `check` | `check-packages`, `update-packages`, `nix-update-pkg`, `symlink-check`, `symlink-check-dms`, `check-zen-essentials` |
| `config` | `init`, `post-install`, `read-defaults`, `setup-age-darwin` |
| `system` | `health`, `rollback`, `reload-services`, `update` |
| `repo` | `git` (fmt + status/log + commit + push) |
| `zen` | `zen-session`, `zen-extract`, `zen-sync`, `zen-compare` |
| `backups` | `backups`, `backups-clean`, `backups-clean-dry` |

The Justfile exports `NH_FLAKE=$FLAKE` so bare `nh` calls target this repo, and
sources `scripts/shell/common.sh` for colored `print_header`, `print_pending`,
`notify`, `get_host`, `is_darwin`, and `prompt_number` helpers.

## Structure

```
flake/
├── flake.nix              # flake-parts entrypoint, inputs, per-system outputs
├── Justfile               # all build/switch/gc/format/repo recipes
├── .flake-host            # active host name (used by `nh`-based recipes)
├── lib/
│   └── pkgs.nix           # getPkgs / getPkgsStable helpers (unfree + overlays)
├── parts/
│   ├── hosts.nix          # builds nixosConfigurations + darwinConfigurations
│   └── overlays/          # per-system nixpkgs overlays
├── data/
│   ├── hosts/hosts.nix    # host definitions (system, username, homeDirectory)
│   └── users/users.nix    # user definitions (jadee, angelie, caya-jonas)
├── hosts/
│   ├── desktop/           # desktop NixOS config (NVIDIA)
│   ├── framework/         # framework NixOS config (AMD, fw-ectool, fw-fanctrl)
│   └── caya/              # caya nix-darwin config + homebrew taps
├── modules/
│   ├── shared/            # cross-platform system modules
│   ├── nixos/             # Linux-only (boot, desktop/niri, services, ...)
│   └── darwin/            # macOS-only
├── home/
│   ├── shared/            # cross-platform home-manager
│   │   ├── apps/          # browsers, editors, IDEs, terminals, tools
│   │   ├── assets/        # fonts, icons, stylix theme, wallpapers
│   │   ├── development/
│   │   │   ├── languages/ # per-language configs
│   │   │   └── tooling/   # cloud, databases, llm, dev tools
│   │   ├── security/      # sops-nix home-manager secrets
│   │   ├── shells/        # bash, fish, nushell, zsh + shared env/paths
│   │   └── utils/         # core, filesystem, monitoring, text tools
│   ├── nixos/             # Linux-only home-manager (desktop, environment, ...)
│   └── darwin/            # macOS-only home-manager
├── packages/              # custom flake packages
│   ├── context7/          # ctx7 CLI
│   ├── kagi-ken/          # kagi search helper
│   ├── kagi-ken-cli/
│   ├── iosevka-aile/
│   ├── iosevka-etoile/
│   ├── workato-platform-cli/
│   └── framework-control/
├── scripts/               # Justfile shell helpers + uv/python package
└── secrets/secrets.yaml   # sops-nix age-encrypted secrets
```

Each category folder has a `default.nix` that auto-imports its siblings.

## Scripts

`scripts/` splits by language. Bash helpers support the Justfile; Python is a
`uv`-managed package (`flake-scripts`) with several console entry points.

```
scripts/
├── shell/
│   ├── common.sh            # sourced by every Justfile recipe
│   ├── just-choose.bash     # fzf recipe picker (default recipe)
│   └── post-install.bash    # Context7 CLI skill install (Claude/Cursor/OpenCode)
├── pyproject.toml           # uv / hatch project `flake-scripts`
└── src/flake_scripts/
    ├── lib/
    │   ├── common.py        # flake paths, Rich consoles
    │   └── palette.py       # hex mirror of home/shared/assets/theme/theme.nix
    ├── symlinks.py          # symlink-check (DMS / niri / quickshell)
    ├── check_packages.py    # scan flake for broken package refs
    ├── read_defaults.py     # macOS `defaults` -> Nix-style output
    ├── update_packages.py   # refresh packages/<name>/default.nix via nix-update or npm/github_npm handlers
    └── zen/
        ├── zen_session.py         # zen-session CLI entry
        ├── extract_pinned_tabs.py # pinned tabs per workspace (JSON/Nix)
        └── sync_flake_profiles.py # write spaces.nix + pins.nix from live Zen
```

Console scripts declared in `scripts/pyproject.toml`:

| Command | What it does |
|---|---|
| `symlink-check` | DMS / niri / quickshell symlink report |
| `check-packages` | Scan flake for broken / missing package references |
| `update-packages` | Bump `packages/*` via `nix-update` or per-package lockfile handlers (driven by `packages/*/update.json`) |
| `read-defaults` | macOS `defaults read <domain>` → Nix-style output |
| `zen-session` | Zen browser session sync + extract (wraps the two below) |

Invoke directly with `uv run --project scripts <command>`, or via the Justfile
recipes in `[group('check')]` / `[group('zen')]`.

## Inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | nixos-unstable |
| `nixpkgs-stable` | nixos-25.11 (available as `pkgs-stable` in modules) |
| `home-manager` | user environment |
| `sops-nix` | secret management (age) |
| `stylix` | system-wide theming |
| `lanzaboote` | secure boot |
| `niri` | Wayland compositor |
| `quickshell` | shell/bar framework |
| `determinate` | Nix daemon |
| `nix-darwin` | macOS config |
| `nix-homebrew` | Homebrew casks declared via Nix |

## specialArgs

Available in every module on top of the nixpkgs defaults:

| Param | Meaning |
|---|---|
| `inputs` | flake inputs |
| `hostData` | all host definitions from `data/hosts/hosts.nix` |
| `hostKey` | active host name (`"desktop"`, `"framework"`, `"caya"`) |
| `host` | current host attrset |
| `user` | current username |
| `isDarwin` | true on macOS |
| `system` | system string (NixOS only) |
| `pkgs-stable` | nixpkgs-stable package set |

## Secrets

Encrypted with age/sops. Edit with `sops secrets/secrets.yaml` (decrypts on
open, re-encrypts on save). Age keys live at `~/.config/sops/age/keys.txt`
(Darwin bootstrap: `just setup-age-darwin`).

Secrets auto-export as env vars in every interactive shell via
`home/shared/shells/sops-shell-secrets.nix`.

```nix
sops.secrets.my_secret = {};
# runtime: config.sops.secrets.my_secret.path
```

## Adding things

| Goal | Location |
|---|---|
| System package, all Linux hosts | `modules/shared/` appropriate category |
| System package, one host only | `hosts/<name>/default.nix` |
| User package (home-manager) | `home/shared/apps/` or relevant category |
| NixOS service/daemon | `modules/nixos/services/` |
| Desktop/Wayland config | `modules/nixos/desktop/` or `home/nixos/desktop/` |
| Language dev config | `home/shared/development/languages/<lang>.nix` |
| Theme / fonts / file symlinks | `home/shared/assets/` |
| Custom package | `packages/<name>/default.nix`, add to `parts/overlays/` if needed |
| New secret | `sops secrets/secrets.yaml`, declare in `modules/shared/security/encryption/age-sops.nix` |

Prefer editing the existing `.nix` file in place. If creating a new file, add
an import in that directory's `default.nix`.

## Workflow

1. Find and edit the right file (see *Adding things*)
2. `just fmt`
3. `just switch` (or `just switch-fast`)
