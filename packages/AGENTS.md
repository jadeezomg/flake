# PACKAGES

## Purpose

Custom flake packages auto-registered into overlays and flake package outputs.

## Use skills

- `flake-structure` — package layout, update metadata, overlays, and package exposure.

## Local hazards

- `packages/*/default.nix` files are auto-registered as `pkgs.<name>`; do not add explicit duplicate imports.
- Updatable packages need `update.json`; `.update-check.json` is generated state with a cooldown.
- Use standard `callPackage` signatures; only accept final `pkgs` when the derivation genuinely needs it.
- Verify packages/dependencies with live nixpkgs tooling and cache availability before adding them.
