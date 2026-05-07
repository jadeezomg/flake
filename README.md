# dotfiles

jadee's NixOS and nix-darwin flake. One `flake-parts` entry point builds three machines with shared home-manager modules on Linux and macOS.

**Full reference:** [AGENTS.md](AGENTS.md) (workflows, profiles, desktop stack, gotchas). This file is the short tour.

## Hosts

| Host        | System          | Hardware              | Notes                                              |
| ----------- | --------------- | --------------------- | -------------------------------------------------- |
| `desktop`   | `x86_64-linux`  | NVIDIA GPU            | `DP-2` @ 2560×1440 / 170 Hz                        |
| `framework` | `x86_64-linux`  | AMD, Framework 13 7040 | `eDP-2` @ 2880×1920 / 120 Hz, 2.0× scale           |
| `caya`      | `aarch64-darwin` | Apple Silicon        | user `caya-jonas`; Homebrew casks via nix-homebrew |

Per-host metadata lives in `hosts/<name>/host.nix`. The registry is `hosts/hosts.nix` (hostnames, users, home directories, main monitor, build cores, DMS/niri config filenames). Linux hosts share `sharedNixOSUser = jadee` and an extra `angelie` account (`hosts/lib.nix`).

The active host is read from **`.flake-host`** (not committed). Set it with `just init` (prompts) or `just _init <host>` (no prompt).

## Conventions

Use **`just` recipes** for builds and switches (not bare `nixos-rebuild` / `home-manager switch` / `nh` without the Justfile). Flakes only see **git-tracked** files: run `git add` before `nix build`, `nix eval`, or anything that must see new files.

For new nixpkgs names, run `nix search nixpkgs <name>` first; check [Hydra](https://hydra.nixos.org/) if you care about binary cache hits ([AGENTS.md](AGENTS.md) has a one-liner).

## Quick start

```bash
# build / switch
just switch          # flake check; runs `just git` first (optional commit) + nh switch
just switch-fast     # nh switch only
just switch-check    # nix flake check only
just build-dry       # dry run (nh darwin build --dry / nh os test)
just build-dev       # switch with --show-trace
just rollback        # previous generation

# format / lint
just fmt             # alejandra + deadnix + ruff + ty + biome
just lint            # deadnix + statix

# maintenance
just update          # update-packages, flake update, fmt; Framework: fwupdmgr when on framework
just gc-days         # nh clean, keep store paths newer than N days
just health          # git status, disk, nh os info
```

`just` alone runs an `fzf` recipe picker (`scripts/shell/just-choose.bash`). `just list` lists every recipe; `just info` shows `nix flake metadata`.

## Justfile groups

| Group         | Recipes |
| ------------- | ------- |
| `build`       | `build`, `build-boot`, `build-dev`, `build-dry` |
| `switch`      | `switch`, `switch-fast`, `switch-check` |
| `generations` | `generation-list`, `generation-switch`, `generation-delete`, `generation-bootloader` |
| `gc`          | `gc` (= `gc-keep`), `gc-days`, `gc-all` |
| `format`      | `fmt`, `fmt-notree`, `lint` |
| `backups`     | `backups`, `backups-clean`, `backups-clean-dry` |
| `check`       | `update-packages`, `nix-update-pkg`, `symlink-check`, `symlink-check-dms` |
| `config`      | `init`, `post-install`, `read-defaults`, `setup-age-darwin` |
| `system`      | `health`, `rollback`, `update` |
| `repo`        | `git` (quiet fmt + status/log + commit + push) |
| `zen`         | `zen-session`, `zen-sync`, `zen-compare`, `zen-extract` |
| `llm`         | `unsloth`, `unsloth-stop`, `unsloth-reset`, `unsloth-logs`, `unsloth-status`, `skills-upstream` |
| `meta`        | `list`, `info` |

`NH_FLAKE` is set to this repo. Shell helpers live in `scripts/shell/common.sh` (`get_host`, `is_darwin`, `notify`, …).

## Layout

```text
flake/
├── flake.nix                 # inputs, per-system packages, formatter = alejandra
├── Justfile
├── .flake-host               # active host (local only)
├── lib/                      # getPkgs / getPkgsStable
├── parts/
│   ├── hosts.nix             # nixosConfigurations + darwinConfigurations
│   ├── shells.nix            # devShell
│   └── overlays/             # local packages, niri, CachyOS kernel, …
├── data/                     # e.g. users/users.nix, static files
├── hosts/                    # hosts.nix + per-host NixOS/darwin config
├── modules/                  # shared / nixos / darwin
├── home/                     # shared, nixos, darwin (home-manager)
├── packages/                 # custom packages; auto-registered as pkgs.<name> (see overlays)
├── agent-skills/             # copy-in agent skills; upstream ref: skills-mattpocock
├── scripts/                  # Justfile helpers + uv Python package (flake-scripts)
└── secrets/secrets.yaml        # sops + age
```

`packages/*` with a `default.nix` is picked up by `parts/overlays/local-packages.nix` (with a system filter for e.g. `framework-control`).

## Scripts

Bash under `scripts/shell/` backs the Justfile. Python is a uv project in `scripts/` (console entry points in `pyproject.toml`): `symlink-check`, `update-packages`, `read-defaults`, `zen-session`, etc. See `scripts/README.md` for details.

## Flake inputs (high level)

| Input | Role |
| ----- | ---- |
| `nixpkgs` | nixos-unstable |
| `nixpkgs-stable` | nixos-25.11 → `pkgs-stable` in modules |
| `nixpkgs-zed` | pinned nixpkgs for Zed (does not follow `nixpkgs`; do not bump accidentally with a blanket `nix flake update`) |
| `home-manager`, `nix-darwin` | user / macOS system config |
| `flake-parts` | module structure |
| `determinate` | Determinate Nix |
| `sops-nix` | secrets |
| `stylix` | theming |
| `lanzaboote` | secure boot (Linux) |
| `niri` | niri compositor (Wayland) |
| `dms` | DankMaterialShell (bar / desktop shell) |
| `quickshell` | shell/bar framework |
| `zen-browser` | Zen browser |
| `nix-homebrew`, `homebrew-*` | Homebrew pins (non-flake fetches) |
| `nixos-hardware` | hardware modules |
| `nix-cachyos-kernel` | CachyOS kernel (x86_64-linux) |
| `framework-control` | Framework laptop tools (separate nixpkgs) |
| `google-workspace-cli` | `gws` in per-system `packages` |
| `agent-sandbox` | sandbox profiles for agents |
| `skills-mattpocock` | optional upstream skills sync via `just skills-upstream` |

`perSystem.packages` in `flake.nix` also exposes: `iosevka-aile`, `iosevka-etoile`, `context7`, `kagi-ken`, `kagi-ken-cli`, `workato-platform-cli`, `gws`, `code-review-graph`, `pi-coding-agent`.

## specialArgs

Available in system/home modules (see [AGENTS.md](AGENTS.md) for the full list): `inputs`, `hostData`, `hostKey`, `host`, `user`, `isDarwin`, `system`, `pkgs-stable`, …

## Secrets

`secrets/secrets.yaml` is encrypted with sops and age. Edit with `sops secrets/secrets.yaml`. Age keys: `~/.config/sops/age/keys.txt` (macOS bootstrap: `just setup-age-darwin`).

Home-manager can export select secrets to the interactive shell via `home/shared/shells/sops-shell-secrets.nix`.

## Where to add things

| Goal | Where |
| ---- | ---- |
| Profile toggles | `dotfiles.profiles` in `modules/shared/profiles/`; enable per host in `hosts/<name>/` |
| System packages (all Linux) | `modules/nixos/` or shared profiles |
| System packages (all hosts) | `modules/shared/profiles/` |
| One host only | `hosts/<name>/` |
| User packages (home-manager) | `home/shared/…` or `home/nixos` / `home/darwin` |
| NixOS services | `modules/nixos/` |
| Desktop / Wayland | `modules/nixos/` and `home/nixos/desktop/` |
| Custom package | `packages/<name>/` + `update.json` when you want `just update-packages` to handle bumps |
| New secret | sops file + declarations (see `modules/shared/security/` / encryption) |

New `.nix` files must be listed in the parent directory’s `default.nix` imports.

## Workflow

1. Edit the right file (table above; details in [AGENTS.md](AGENTS.md)).
2. `just fmt`
3. `just switch` or `just switch-fast`
4. After desktop config edits, `just symlink-check` (and reload compositor / session tools as needed).

---

*Theme, Stylix, niri, DMS, and recovery topics are documented in [AGENTS.md](AGENTS.md).*
