# dotfiles

jadee's NixOS and nix-darwin flake. One `flake-parts` entry point builds four machines with shared home-manager modules on Linux and macOS.

Agents start at [AGENTS.md](AGENTS.md). It lists the local hazards and the project skills in `.agents/skills/` that hold the layout rules. This file is the short tour.

## Hosts

| Host        | System          | Hardware              | Notes                                              |
| ----------- | --------------- | --------------------- | -------------------------------------------------- |
| `desktop`   | `x86_64-linux`  | NVIDIA GPU            | Dell AW3926QW 5120×2160 / 165 Hz + Dell S2722QC 3840×2160 / 60 Hz (portrait) |
| `framework` | `x86_64-linux`  | AMD, Framework 13 7040 | `eDP-1` @ 2880×1920 / 120 Hz, 1.4× scale           |
| `caya`      | `aarch64-darwin` | Apple Silicon, M4 MacBook Air | user `jonashippauf` (`caya-jonas` in `data/users/users.nix`), Homebrew casks via nix-homebrew |
| `mini`      | `x86_64-linux`  | Minisforum MS-01     | headless server, `hostClass = "server"`, static LAN `192.168.178.100`. The firewall trusts `tailscale0`, and SSH is also open on the LAN |

Per-host metadata lives in `hosts/<name>/host.nix`. The registry is `hosts/hosts.nix` (hostnames, users, home directories, build cores, DMS and niri file names, host class). Linux hosts share `sharedNixOSUser = jadee` and an extra `angelie` account (`hosts/lib.nix`). `mini` opts out with `extraUsers = []`, because a headless server has no guest accounts.

The flake reads the active host from `.flake-host`, which is not committed. To set it, run `just init` (it prompts) or `just _init <host>` (no prompt).

`mini` is the headless server (Minisforum MS-01). It runs local LLM chat and embeddings (llama.cpp, `mini llm`), Beszel monitoring, and Atuin shell-history sync. It also runs the Nixflix media stack (Jellyfin, VPN-confined downloaders, payloads on Unraid) and an Immich photo library with off-host backups. Its service modules, `mini/**` secrets, service notes and service ADRs live in the private mini-nix repo. That repo is the `mini-nix` flake input, which `hosts/mini/default.nix` imports. The machine notes are in [`docs/hosts/mini.md`](docs/hosts/mini.md). To deploy, run `mini deploy`. Its recipes are in mini-nix.

## Conventions

Use the `just` recipes for builds and switches. Do not run bare `nixos-rebuild`, `home-manager switch` or `nh` without the Justfile. Flakes only see files that git tracks. Run `git add` before `nix build`, `nix eval`, or anything else that must see new files.

Before you add a nixpkgs name, run `nix search nixpkgs <name>`. [Hydra](https://hydra.nixos.org/) shows the binary cache state of a package. The `overlays` skill (`.agents/skills/overlays/SKILL.md`) has a one-line command for the same check.

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

`just` with no recipe runs `tv just-recipes`. The cable TOML is in `modules/profiles/essentials/utils/television/cable/`. Home Manager links it to `~/.config/television/cable/`, the same way as the navi cheats. F5 runs the highlighted recipe (`just` in execute mode). If `tv` is not on `PATH`, install the `television` package or run `just --choose`. `just list` lists every recipe, and `just info` shows `nix flake metadata`.

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

`mini <cmd>` is a separate command, not a group in this Justfile. It runs the Justfile of the private mini-nix repo (`modules/profiles/minimal/shells/mini-cli.nix`). Its recipes are `pull`, `deploy`, `deploy-dry`, `deploy-boot`, `bump`, `ship`, `ssh`, `reboot`, `dns-sync` and `secret-set`. It also has status and restart recipes for hermes, media, immich and immich-backup. The `llm` sub-module has `models`, `chat`, `perf`, `embedding`, `bench` and more.

`NH_FLAKE` points at this repo. Shell helpers live in `scripts/shell/common.sh` (`get_host`, `is_darwin`, `notify`, …).

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

`parts/overlays/local-packages.nix` picks up each `packages/*` folder that has a `default.nix`.

## Scripts

The Bash scripts in `scripts/shell/` back the Justfile, including the host-ops helpers (`flatten-dir.bash`, `sync-1password.bash`, …). The `mini` command also runs `mini-*.bash` and `dns-sync.bash` from this checkout. `scripts/` is also a uv Python project. Its console entry points are in `pyproject.toml`: `symlink-check`, `update-packages`, `zen-sync` and `vorssaint-sync`. `scripts/README.md` has the details.

## Flake inputs (high level)

| Input | Role |
| ----- | ---- |
| `nixpkgs` | nixos-unstable |
| `nixpkgs-small` | nixos-unstable-small (exposed through `lib/pkgs.nix` → `getPkgsSmall`) |
| `nixpkgs-stable` | nixos-26.05 → `pkgs-stable` in modules |
| `nixpkgs-skhd` | pinned nixpkgs for skhd, so that the macOS Accessibility grant stays valid. A standing pin, not a workaround (`parts/overlays/skhd-pinned-darwin.nix`) |
| `systems` | this repo's `lib/systems.nix` (drops `x86_64-darwin` from the systems list) |
| `home-manager`, `nix-darwin` | user / macOS system configuration |
| `flake-parts` | module structure |
| `determinate` | Determinate Nix |
| `sops-nix` | secrets |
| `stylix` | theming |
| `lanzaboote` | secure boot (Linux) |
| `disko` | disk partitioning (mini: `hosts/mini/disko.nix`) |
| `dms` | DankMaterialShell (bar / desktop shell) |
| `dank-greeter`, `dankcalendar` | DMS greeter / calendar widget |
| `noctalia` | Noctalia v5 shell (DMS alternative on niri, flake TOML through HM `settings`) |
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
| `hermes-agent` | Hermes agent NixOS module. mini-nix runs `services.hermes-agent` on mini |
| `corecycler` | CoreCycler stability tester on desktop (`hosts/desktop/corecycler.nix`) |
| `delta` | Zed's Delta, Linux only (`modules/profiles/devgui/ides/default.nix`) |

`packages.<system>` exposes every `packages/<name>` automatically (`parts/packages.nix` + `packages/names.nix`).

## specialArgs

Available in system/home modules (see `parts/hosts.nix` for the full list): `inputs`, `hostData`, `hostKey`, `host`, `user`, `isDarwin`, `system`, `pkgs-stable`, …

## Secrets

`secrets/secrets.yaml` is encrypted with sops and age. See [docs/secrets/sops-age-keys.md](docs/secrets/sops-age-keys.md). Edit it with `sops secrets/secrets.yaml`. Editor key: `just setup-age-editor` → `~/.config/sops/age/keys.txt`.

Home Manager exports some secrets to the user session environment through `modules/profiles/minimal/shells/sops-session-env.nix`. On Linux it uses env.d and `systemctl --user set-environment`. On Darwin it uses a LaunchAgent and `launchctl setenv`. Every new shell gets them, and so does every GUI app started outside a terminal.

## Where to add things

| Goal | Where |
| ---- | ---- |
| Profile toggles | `dotfiles.profiles` in `modules/profiles/`. Enable them per host in `hosts/<name>/` |
| Profiles overview | [`docs/profiles.md`](docs/profiles.md) (structure and conventions). The tree is its own index |
| Architecture decisions | [`docs/adr/`](docs/adr/) (agent sandboxing). The mini service ADRs are in mini-nix |
| Host ops / troubleshooting | [`docs/hosts/`](docs/hosts/) (for example [`docs/hosts/mini.md`](docs/hosts/mini.md)) |
| System packages (profile-gated) | `modules/profiles/<profile>.nix` (platform extras inline) |
| System packages (unconditional base) | `modules/shared/`, `modules/nixos/`, `modules/darwin/` |
| One host only | `hosts/<name>/` |
| User (HM) configuration | the owning profile's feature folder in `modules/profiles/` (pushed through `home-manager.sharedModules`) |
| NixOS services | `modules/nixos/` |
| Desktop / Wayland | `modules/profiles/desktop/` (system + DMS or Noctalia/niri HM + data) |
| Custom package | `packages/<name>/`. Add `update.json` so that `just update-packages` handles its bumps |
| mini service or `mini/**` secret | the private mini-nix repo (`~/git/mini-nix`), then `mini bump` to pin it here |
| New secret | sops file + declarations (see the `secrets-structure` skill and `secrets/SCHEMA.md`) |

List each new `.nix` file in the imports of the `default.nix` in its parent folder.

## Workflow

1. Edit the right file. Use the table above, and [AGENTS.md](AGENTS.md) for the details.
2. `just fmt`
3. `just switch` or `just switch-fast`
4. After you edit the desktop files, run `just symlink-check`. If the compositor or the session tools need it, reload them.

---

*Theme and Stylix rules are in the `theme-structure` skill. The niri, Umbriel, Noctalia and DMS file layout is in the `desktop-session` skill. Host recovery notes are in [`docs/hosts/`](docs/hosts/).*
