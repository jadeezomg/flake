---
name: flake-structure
description: Apply this dotfiles flake's top-level layout rules. Use when adding, moving, or reorganizing hosts, flake-parts, custom packages, shared lib helpers, scripts, docs, or other non-profile flake structure.
---

# Flake Structure

## Scope

Use this for top-level flake organization outside `modules/profiles/**`. For profile/app layout, use `module-structure`; for `parts/overlays/` internals, use `overlays`.

## Top-level ownership

- `hosts/<name>/` owns per-machine facts and overrides.
  - `host.nix`: host facts such as hostname, monitors, hardware knobs, `nixpkgsConfig`.
  - `profiles.nix`: `dotfiles.profiles.*` toggles.
  - `default.nix`: host-specific system overrides and packages.
- `parts/` owns flake-parts wiring.
  - `hosts.nix`: NixOS/Darwin/HM output construction.
  - `packages.nix`: exposes local packages as flake packages.
  - `checks.nix`: flake checks and formatter.
  - `overlays/`: overlay list and package auto-registration — see the `overlays` skill.
- `packages/<name>/` owns custom package derivations and update metadata.
- `lib/` owns shared data/helpers exposed through `dotfilesLib`.
- `scripts/` owns Justfile-backed shell/Python helpers.
- `docs/` owns durable explanations, ADRs, and operator references.

## Host structure

Each host has:

- `host.nix`: facts: hostname, monitor data, extra users, secure boot, host import-time nixpkgs config.
- `profiles.nix`: profile toggles.
- `default.nix`: host-specific system overrides.

Hazards:

- `.flake-host` selects the active host and must not be committed.
- `stateVersion` is per-host; never raise it without release-note audit and never lower it.
- `extraUsers` also receive Home Manager configs through `parts/hosts.nix`.
- Host-specific nixpkgs import config belongs in `host.nix` as `nixpkgsConfig`, consumed by `getPkgsWithConfig`.

## Flake-parts wiring

- `mkHostOutputs` builds per-host outputs keyed by `host.hostname` with `hostKey` fallback.
- Single-host modules belong in `hosts/<name>/default.nix`, not common platform imports.
- `homeModules` is the unconditional HM base; profile/user config arrives through `home-manager.sharedModules`.
- `packages.nix` and `parts/overlays/local-packages.nix` share `packages/names.nix`.
- `checks.nix` owns flake checks; darwin eval checks are explicit because `flake check` ignores `darwinConfigurations`.
- `nixpkgs-zed` is pinned separately; do not make it follow `nixpkgs` accidentally.

## Lib structure

- Expose cross-tree pure data/helpers through `lib/default.nix` as `dotfilesLib`.
- Do not add `../../` module imports for shared data.
- `pkgs.nix` owns `getPkgs`, `getPkgsWithConfig`, `getPkgsSmall`, and `getPkgsStable`.
- `home/dotfiles.nix` owns `dotfiles.flakeRoot` for live symlink targets.

## Package structure

- Local packages are auto-registered from `packages/*/default.nix`; do not add duplicate explicit imports.
- Every updatable package should have `update.json` beside `default.nix`.
- Update types include `nix-update`, `npm`, `github_npm`, and `binary_channel`.
- `.update-check.json` is generated cooldown state.
- Use standard `callPackage` conventions; accept final `pkgs` only when needed.
- Verify packages/dependencies with live nixpkgs tooling and cache availability before adding them.

## Script structure

- Shell helpers live in `scripts/shell/` and should reuse `common.sh`.
- Python automation lives in `scripts/src/flake_scripts/`, with entry points in `scripts/pyproject.toml`.
- Use `uv run --project scripts <entry-point>` from recipes.
- Shell helpers are bash-only; use `[[ ]]`, not `[ ]`.
- New scripts must be staged before Nix eval/build.
- If theme colors are used in Python, keep `scripts/src/flake_scripts/lib/palette.py` in sync with `lib/theme-palette.nix`.

## Docs structure

- Use `CONTEXT.md` for domain vocabulary and current architecture map.
- Use `docs/adr/` for durable decisions with tradeoffs.
- Use focused docs under `docs/<area>/` for operator procedures.
- Do not create docs just to narrate a small code change.

## Checks

1. Run `just fmt` for Nix/script changes.
2. `git add` new Nix/package/script files before Nix eval/build.
3. Eval the changed flake output or package attr directly.
4. Run the narrow recipe/check that covers the moved owner.
