---
name: flake-structure
description: Apply this dotfiles flake's top-level layout rules. Use when adding, moving, or reorganizing hosts, flake-parts, custom packages, shared lib helpers, data registries, scripts, just modules, docs, or other non-profile flake structure.
---

# Flake Structure

## Scope

This skill maps the tree outside `modules/profiles/**`. For profile and app layout, use `module-structure`. For `parts/overlays/` internals, use `overlays`. For `secrets/` and `.sops.yaml`, use `secrets-structure`. For `data/agents/`, use `agent-structure`.

## Top-level map

- `flake.nix`: inputs and the flake-parts `imports` list. `systems` is a `flake = false` path input that points at `lib/systems.nix`.
- `hosts/`: host registry and per-machine config.
- `parts/`: flake-parts modules.
- `modules/`: NixOS, Darwin, and Home Manager modules (see `module-structure`).
- `packages/`: custom package derivations and update metadata.
- `lib/`: shared data and helpers exposed as `dotfilesLib`.
- `data/`: plain data registries with no Nix logic.
- `scripts/`: bash helpers and the `flake-scripts` Python project.
- `Justfile` and `just/`: operator recipes.
- `docs/`: durable explanations and ADRs.
- `secrets/` and `.sops.yaml`: SOPS/age secrets.
- Subdirectory `CLAUDE.md` files contain only `@AGENTS.md`. Put the content in `AGENTS.md`.

## Inputs

- `nixpkgs` is the main channel. `nixpkgs-small` and `nixpkgs-stable` back `getPkgsSmall` and `getPkgsStable` in `lib/pkgs.nix`.
- `nixpkgs-skhd` is a standing pin with no expiry guard. `parts/overlays/skhd-pinned-darwin.nix` consumes it.
- `nixpkgs-zed` is declared but has no consumer. Do not document it as live.

## Hosts

- `hosts/hosts.nix` is the host registry. It imports each `hosts/<name>/host.nix` and validates the required fields: `hostname`, `system`, `username`, `stateVersion`. A new host must be registered here.
- `hosts/hosts.nix` defaults `sshAddress` to `hostname`. A host sets `sshAddress = null` to opt out (caya) or a fixed address (mini). `data/network/ssh-destinations.nix` consumes it.
- `hosts/lib.nix` holds shared host defaults: `sharedNixOSHost`, `sharedNixOSUser`, `darwinUser`, `nixosExtraUsers`. It reads `data/users/users.nix`.
- Each `hosts/<name>/` has:
  - `host.nix`: facts such as `hostname`, `hostClass` (`workstation` or `server`), `buildCores`, `extraUsers`, monitor data, `nixpkgsConfig`.
  - `profiles.nix`: `dotfiles.profiles.*` toggles.
  - `default.nix`: host-specific system overrides and single-host modules.

Hazards:

- `.flake-host` selects the active host. Never commit it. Never create, edit, or delete it.
- `stateVersion` is per-host. Never raise it without a release-note audit. Never lower it.
- `extraUsers` also get Home Manager configs through `parts/hosts.nix`.
- Host nixpkgs import config belongs in `host.nix` as `nixpkgsConfig`. `getPkgsWithConfig` consumes it.

## Flake-parts wiring

- `parts/hosts.nix`: `mkHostOutputs` builds `nixosConfigurations` or `darwinConfigurations`, keyed by `host.hostname`. Home Manager is embedded in each system output. There are no `homeConfigurations` outputs.
- `homeModules` in `parts/hosts.nix` is the unconditional HM base. Profile and user config arrives through `home-manager.sharedModules`.
- Single-host modules belong in `hosts/<name>/default.nix`, not in the common module lists.
- `parts/shells.nix`: `devShells` (`default`, `nono-claude`, `nono-pi`) built from `lib/nono-profiles.nix`.
- `parts/packages.nix`: exposes local packages as flake `packages` and pins `perSystem` `pkgs` to `getPkgs`.
- `parts/checks.nix`: `host-caya-eval` (aarch64-darwin), `host-mini-headless` (x86_64-linux), and `formatter = nixfmt-tree`. Darwin eval is explicit because `flake check` ignores `darwinConfigurations`.
- `parts/overlays/`: overlay list and local package registration. See the `overlays` skill.

## Lib

- `lib/default.nix` builds `dotfilesLib`. `parts/hosts.nix` passes it to every system and HM module. Do not add `../../` imports for shared data.
- `lib/default.nix` reads two address registries and keeps them apart: `hostFacts` (machines the flake builds, from `hosts/hosts.nix`) and `lanHosts` (machines it only talks to, from `data/network/lan-hosts.nix`).
- `pkgs.nix`: `getPkgs`, `getPkgsWithConfig`, `getPkgsSmall`, `getPkgsStable`.
- `systems.nix`: the supported systems list.
- `expiry.nix`: expiry guard for workaround overlays.
- `nix-caches.nix`, `nix-experimental-features.nix`: Nix settings data.
- `host-status.nix`, `nono-profiles.nix`: helpers applied with `pkgs`.
- `theme-palette.nix`, `theme-base16.nix`, `theme-fonts.nix`: theme data (see `theme-structure`).
- `shells/env-data.nix`, `shells/paths.nix`: shell env and path data.
- `packages/minimal.nix`: the minimal package set.
- `home/dotfiles.nix`: the `dotfiles.flakeRoot` option and `config.lib.dotfiles`. `home/live-xdg-symlinks.nix`: live symlink helpers.

## Data

- `data/network/lan-hosts.nix`: addresses of machines the flake does not build.
- `data/network/ssh-destinations.nix`: ssh aliases derived from both registries.
- `data/users/users.nix`: the account registry.
- `data/files/`: static files that modules symlink live.
- `data/agents/`: agent config data (see `agent-structure`).

## Packages

- `packages/names.nix` lists every `packages/<name>/default.nix`. `parts/packages.nix` and `parts/overlays/local-packages.nix` share it. Do not add explicit imports.
- Every updatable package has `update.json` beside `default.nix`. `.update-check.json` is generated cooldown state.
- Update types: `nix-update` (built in), `binary_channel`, `fetchzip`, `npm`. `fetchzip` serves `iosevka-aile` and `iosevka-etoile`.
- Use standard `callPackage` conventions. Verify packages with live nixpkgs tooling before you add them.

## Scripts

- `scripts/shell/`: bash helpers that source `common.sh`. Use `[[ ]]`, not `[ ]`.
- `scripts/src/flake_scripts/`: Python package. Subpackages: `lib/` (`common.py`, `palette.py`) and `zen/` (`session.py`, `sync.py`).
- Entry points in `scripts/pyproject.toml`: `symlink-check`, `zen-sync`, `update-packages`, `media-quality`.
- Recipes call `uv run --project "$FLAKE/scripts" <entry-point>`.
- Keep `scripts/src/flake_scripts/lib/palette.py` in sync with `lib/theme-palette.nix`.

## Just

- `Justfile` loads `just/mini.just` as `mod mini` and `just/unraid.just` as `mod unraid`.
- `just/mini.just` nests `just/mini-llm.just` as `mod llm` (`just mini llm <cmd>`).
- `flake <recipe>` is a shell alias for `just --justfile $FLAKE/Justfile <recipe>`.

## Docs

- `docs/ALIASES.md`: shell alias reference. `docs/profiles.md`: profile reference.
- `docs/adr/`: numbered ADRs for durable decisions.
- `docs/bench/`, `docs/handoffs/`, `docs/hosts/`, `docs/nix/`, `docs/research/`, `docs/secrets/`: focused notes by area.
- `CONTEXT.md` at the root defines agent sandboxing vocabulary.
- Do not create docs to narrate a small code change.

## Checks

1. Run `flake fmt` after Nix or script changes.
2. `git add` new files before Nix eval or build.
3. Ask the user to run builds. Do not run them yourself.
