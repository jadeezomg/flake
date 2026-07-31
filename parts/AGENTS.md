# PARTS

## Purpose

flake-parts modules that assemble hosts, Home Manager configs, packages, checks, lib outputs, and overlays.

## Use skills

- `flake-structure` — flake-parts ownership, package exposure, and checks.
- `overlays` — `parts/overlays/` layout and the self-expiring workaround pattern.
- `agent-structure` — agent-related flake wiring.

## Local hazards

- `nixosConfigurations.*` and `darwinConfigurations.*` are keyed by host `hostname` with `hostKey` fallback.
- Single-host modules belong in `hosts/<name>/default.nix`, not common platform imports.
- `homeModules` is the flat unconditional HM base; profiles push user config through `home-manager.sharedModules`.
- Local packages are auto-registered by `parts/overlays/local-packages.nix` from `packages/names.nix`; do not add a second registry.
- Workaround overlays guard themselves with `parts/overlays/expiry.nix`; guard attribute values, never the attrset an overlay returns (infinite recursion).
