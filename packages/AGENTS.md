# PACKAGES

Custom flake packages. All `packages/*/default.nix` files are auto-registered as `pkgs.<name>` via `parts/overlays/local-packages.nix` — no explicit import needed.

## Calling Conventions

```nix
{ pkgs, lib, ... }:                              # pkgs = final; injected automatically
{ lib, rustPlatform, fetchFromGitHub, ... }:    # standard callPackage convention
```

## update.json Types

Every updatable package has an `update.json`:

| Type | Behaviour |
|------|-----------|
| `nix-update` | delegates to `nix-update --flake <attr>` (most packages) |
| `npm` | npm registry packages |
| `github_npm` | GitHub releases + npm lock regeneration |
| `binary_channel` | version URL + platform hash map |

`.update-check.json` stores last-checked timestamp; 1h cooldown. Override with `UPDATE_FORCE=1`.

