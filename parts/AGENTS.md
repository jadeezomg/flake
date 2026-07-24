# PARTS

## Purpose

flake-parts modules that assemble hosts, Home Manager configs, packages, checks, lib outputs, and overlays.

## Use skills

- `flake-structure` — flake-parts ownership, package exposure, checks, and overlays.
- `agent-structure` — agent-related flake wiring.

## Local hazards

- `nixosConfigurations.*` and `darwinConfigurations.*` are keyed by host `hostname` with `hostKey` fallback.
- Single-host modules belong in `hosts/<name>/default.nix`, not common platform imports.
- `homeModules` is the flat unconditional HM base; profiles push user config through `home-manager.sharedModules`.
- Local packages are auto-registered by `parts/overlays/local-packages.nix` from `packages/names.nix`; do not add a second registry.
