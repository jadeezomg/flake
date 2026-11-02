# dotfiles

jadee's NixOS and nix-darwin flake. One `flake-parts` entry point builds four machines with shared home-manager modules on Linux and macOS.

**Agent guide:** [AGENTS.md](AGENTS.md) (local hazards, and the project skills in `.agents/skills/` that hold the layout rules). This file is the short tour.

## Hosts

| Host        | System          | Hardware              | Notes                                              |
| ----------- | --------------- | --------------------- | -------------------------------------------------- |
| `desktop`   | `x86_64-linux`  | NVIDIA GPU            | Dell AW3926QW 5120×2160 / 165 Hz + Dell S2722QC 3840×2160 / 60 Hz (portrait) |
| `framework` | `x86_64-linux`  | AMD, Framework 13 7040 | `eDP-1` @ 2880×1920 / 120 Hz, 1.4× scale           |
| `caya`      | `aarch64-darwin` | Apple Silicon, M4 MacBook Air | user `jonashippauf` (`caya-jonas` in `data/users/users.nix`), Homebrew casks via nix-homebrew |
| `mini`      | `x86_64-linux`  | Minisforum MS-01     | headless server; `hostClass = "server"`; static LAN `192.168.178.100`; firewall trusts `tailscale0`, SSH also open on the LAN |

Per-host metadata lives in `hosts/<name>/host.nix`. The registry is `hosts/hosts.nix` (hostnames, users, home directories, build cores, DMS/niri config filenames, host class). Linux hosts share `sharedNixOSUser = jadee` and an extra `angelie` account (`hosts/lib.nix`); `mini` opts out (`extraUsers = []` — no guest accounts on a headless server).

The active host is read from **`.flake-host`** (not committed). Set it with `just init` (prompts) or `just _init <host>` (no prompt).

**`mini`** is the headless server (Minisforum MS-01): local LLM chat + embeddings (llama.cpp via `mini llm`), Beszel monitoring, Atuin shell-history sync, the Nixflix media stack (Jellyfin, VPN-confined downloaders, Unraid payloads, see `docs/adr/` in mini-nix), and an Immich photo library with off-host backups. Ops notes live in [`docs/hosts/mini.md`](docs/hosts/mini.md); deploy with `mini deploy` (recipes live in the private mini-nix repo). mini's service modules and `mini/**` secrets also live in mini-nix, the `mini-nix` flake input that `hosts/mini/default.nix` imports.

## Conventions

Use **`just` recipes** for builds and switches (not bare `nixos-rebuild` / `home-manager switch` / `nh` without the Justfile). Flakes only see **git-tracked** files: run `git add` before `nix build`, `nix eval`, or anything that must see new files.

For new nixpkgs names, run `nix search nixpkgs <name>` first; check [Hydra](https://hydra.nixos.org/) if you care about binary cache hits (the `overlays` skill in `.agents/skills/overlays/SKILL.md` has a one-liner).

## Quick start

```bash
# build / switch
just switch          # flake check → build → commit on success → quit apps (macOS) → activate; errors → clipboard
just switch-fast     # nh switch only
just quit-apps       # macOS: ask open apps to quit, never forced (--dry-run lists them)
just switch-check    # nix flake check only
just build-dry       # dry run (nh darwin build --dry / nh os build --dry)
just build-dev       # switch with --show-trace
just rollback        # previous generation

# format / lint
just fmt             # treefmt + deadnix + ruff + ty + biome
just lint            # deadnix + statix

# maintenance
just update          # update-packages, flake update, fmt; Framework: fwupdmgr when on framework
just gc-days         # nh clean, keep store paths newer than N days
just health          # git status, disk, nh os info
```

`just` alone runs **`tv just-recipes`** (cable TOML in `modules/profiles/essentials/utils/television/cable/`; Home Manager links it to **`~/.config/television/cable/`** like navi cheats). **F5** runs the highlighted recipe (`just` in execute mode). Install the `television` package so `tv` is on `PATH`, or run `just --choose` yourself. `just list` lists every recipe; `just info` shows `nix flake metadata`.

## Justfile groups

| Group         | Recipes |
| ------------- | ------- |
| `build`       | `build`, `build-boot`, `build-dev`, `build-dry` |
| `switch`      | `switch`, `switch-fast`, `switch-check`, `quit-apps` |
| `generations` | `generation-list`, `generation-switch`, `generation-delete`, `generation-bootloader` |
| `gc`          | `gc` (= `gc-keep`), `gc-days`, `gc-all` |
| `format`      | `fmt`, `fmt-notree`, `lint` |
| `backups`     | `backups`, `backups-clean`, `backups-clean-dry` |
| `check`       | `update-packages`, `nix-update-pkg`, `symlink-check`, `symlink-check-dms` |
| `config`      | `init`, `_init`, `secret-set`, `setup-age-editor`, `setup-age-darwin`, sops host-key lifecycle (`bootstrap-sops-host-key`, `bootstrap-sops-host-key-from-editor`, `rotate-sops-host-key`, `verify-sops-host-key`), `sync-1password`, `sync-media-secrets-to-pass` |
| `system`      | `health`, `rollback`, `update`, `flatten-dir`, `flatten-dir-dry`, `wow-ui` |
| `repo`        | `git` (quiet fmt + status/log + commit + push) |
| `zen`         | `zen-sync`, `zen-check` |
| `vorssaint`   | `vorssaint-sync`, `vorssaint-check` |
| `llm`         | `unsloth`, `unsloth-stop`, `unsloth-reset`, `unsloth-logs`, `unsloth-status` (mini: `mini llm`) |
| `unraid`      | `just unraid <cmd>`: `ssh`, `fancurve-deploy`, `fancurve-status` |
| `meta`        | `list`, `info` |

`mini <cmd>` is a separate command, not a group in this Justfile. It runs the Justfile of the private mini-nix repo (`modules/profiles/minimal/shells/mini-cli.nix`): `pull`, `deploy`, `deploy-dry`, `deploy-boot`, `bump`, `ship`, `ssh`, `reboot`, `dns-sync`, `secret-set`, hermes/media/immich/immich-backup status + restart, and the `llm` sub-module (`models`, `chat`, `perf`, `embedding`, `bench`, …).

`NH_FLAKE` is set to this repo. Shell helpers live in `scripts/shell/common.sh` (`get_host`, `is_darwin`, `notify`, …).

## Layout

```text
flake/
├── flake.nix                 # inputs, per-system packages, formatter = nixfmt-tree
├── Justfile                  # root recipes + module imports
├── just/                     # Justfile modules: unraid.just
├── .flake-host               # active host (local only)
├── lib/                      # getPkgs / getPkgsStable / getPkgsSmall / getPkgsWithConfig
├── parts/
│   ├── hosts.nix             # nixosConfigurations + darwinConfigurations
│   ├── shells.nix            # devShell
│   ├── packages.nix          # exposes packages/<name> as flake `packages`
│   ├── checks.nix            # eval-level flake checks + formatter
│   └── overlays/             # local packages, skhd pin, CachyOS kernel, …
├── .agents/skills/           # project-only agent skills (repo discovery)
├── data/                     # e.g. users/users.nix, static files
├── hosts/                    # hosts.nix + per-host NixOS/darwin config
├── modules/                  # profiles (features, system + HM halves) / platform base
├── packages/                 # custom packages; auto-registered as pkgs.<name> (see overlays)
├── data/agents/              # global AGENTS.md + local skills + Claude Code mods
├── docs/                     # ADRs (docs/adr), host runbooks (docs/hosts), plans, research
├── scripts/                  # Justfile helpers + uv Python package (flake-scripts)
└── secrets/secrets.yaml        # sops + age
```

`packages/*` with a `default.nix` is picked up by `parts/overlays/local-packages.nix`.

## Scripts

Bash under `scripts/shell/` backs the Justfile — including host-ops helpers (`flatten-dir.bash`, `sync-1password.bash`, …). The `mini` command also runs `mini-*.bash` and `dns-sync.bash` from this checkout. Python is a uv project in `scripts/` (console entry points in `pyproject.toml`): `symlink-check`, `update-packages`, `zen-sync`, `vorssaint-sync`. See `scripts/README.md` for details.

## Flake inputs (high level)

| Input | Role |
| ----- | ---- |
| `nixpkgs` | nixos-unstable |
| `nixpkgs-small` | nixos-unstable-small (exposed via `lib/pkgs.nix` → `getPkgsSmall`) |
| `nixpkgs-stable` | nixos-26.05 → `pkgs-stable` in modules |
| `nixpkgs-skhd` | pinned nixpkgs for skhd (macOS Accessibility grant; standing pin, not a workaround — `parts/overlays/skhd-pinned-darwin.nix`) |
| `systems` | this repo's `lib/systems.nix` (drops `x86_64-darwin` from the systems list) |
| `home-manager`, `nix-darwin` | user / macOS system config |
| `flake-parts` | module structure |
| `determinate` | Determinate Nix |
| `sops-nix` | secrets |
| `stylix` | theming |
| `lanzaboote` | secure boot (Linux) |
| `disko` | disk partitioning (mini: `hosts/mini/disko.nix`) |
| `dms` | DankMaterialShell (bar / desktop shell) |
| `dank-greeter`, `dankcalendar` | DMS greeter / calendar widget |
| `noctalia` | Noctalia v5 shell (DMS alternative on niri; flake TOML via HM `settings`) |
| `quickshell` | shell/bar framework |
| `zen-browser` | Zen browser |
| `vicinae`, `vicinae-extensions` | Vicinae browser integration (Zen native-messaging host) |
| `nix-flatpak` | declarative Flatpak remotes/packages (`modules/profiles/integrations.nix`) |
| `nixflix` | Jellyfin/Plex wrapper for mini's media stack (used by mini-nix) |
| `mini-nix` | private repo with mini's service modules and `mini/**` secrets (`hosts/mini/default.nix`) |
| `nix-homebrew`, `homebrew-*` | Homebrew pins (non-flake fetches) |
| `nixos-hardware` | hardware modules |
| `nix-cachyos-kernel` | CachyOS kernel (x86_64-linux) |
| `llm-agents` | agent CLI overlay (`pkgs.llm-agents.*`: codex, claude-code, pi, omp, apm, nono, herdr, …) |
| `hermes-agent` | Hermes agent NixOS module; mini-nix runs `services.hermes-agent` on mini |
| `corecycler` | CoreCycler stability tester on desktop (`hosts/desktop/corecycler.nix`) |
| `delta` | Zed's Delta, Linux only (`modules/profiles/devgui/ides/default.nix`) |

`packages.<system>` exposes every `packages/<name>` automatically (`parts/packages.nix` + `packages/names.nix`).

## specialArgs

Available in system/home modules (see `parts/hosts.nix` for the full list): `inputs`, `hostData`, `hostKey`, `host`, `user`, `isDarwin`, `system`, `pkgs-stable`, …

## Secrets

`secrets/secrets.yaml` is encrypted with sops and age. See [docs/secrets/sops-age-keys.md](docs/secrets/sops-age-keys.md). Edit with `sops secrets/secrets.yaml`. Editor key: `just setup-age-editor` → `~/.config/sops/age/keys.txt`.

Home-manager exports select secrets to the user session env via `modules/profiles/minimal/shells/sops-session-env.nix` (env.d + `systemctl --user set-environment` on Linux; LaunchAgent + `launchctl setenv` on Darwin), so every new shell — and GUI apps launched outside a terminal — inherit them.

## Where to add things

| Goal | Where |
| ---- | ---- |
| Profile toggles | `dotfiles.profiles` in `modules/profiles/`; enable per host in `hosts/<name>/` |
| **Profiles overview** | [`docs/profiles.md`](docs/profiles.md) (structure + conventions; the tree is its own index) |
| Architecture decisions | [`docs/adr/`](docs/adr/) (agent sandboxing). The mini service ADRs are in mini-nix. |
| Host ops / troubleshooting | [`docs/hosts/`](docs/hosts/) (e.g. [`docs/hosts/mini.md`](docs/hosts/mini.md)) |
| System packages (profile-gated) | `modules/profiles/<profile>.nix` (platform extras inline) |
| System packages (unconditional base) | `modules/shared/`, `modules/nixos/`, `modules/darwin/` |
| One host only | `hosts/<name>/` |
| User (HM) config | the owning profile's feature folder in `modules/profiles/` (pushed via `home-manager.sharedModules`) |
| NixOS services | `modules/nixos/` |
| Desktop / Wayland | `modules/profiles/desktop/` (system + DMS or Noctalia/niri HM + data) |
| Custom package | `packages/<name>/` + `update.json` when you want `just update-packages` to handle bumps |
| mini service or `mini/**` secret | the private mini-nix repo (`~/git/mini-nix`), then `mini bump` to pin it here |
| New secret | sops file + declarations (see the `secrets-structure` skill and `secrets/SCHEMA.md`) |

New `.nix` files must be listed in the parent directory’s `default.nix` imports.

## Workflow

1. Edit the right file (table above; details in [AGENTS.md](AGENTS.md)).
2. `just fmt`
3. `just switch` or `just switch-fast`
4. After desktop config edits, `just symlink-check` (and reload compositor / session tools as needed).

---

*Theme and Stylix rules are in the `theme-structure` skill. The niri and DMS file layout is in the `module-structure` skill. Host recovery notes are in [`docs/hosts/`](docs/hosts/).*
