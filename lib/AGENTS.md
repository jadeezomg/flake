# LIB

## Purpose

Shared Nix data and helpers exposed to modules through `dotfilesLib` and Home Manager helper modules.

## Use skills

- `flake-structure` — what belongs in `lib/` and how it is exposed.
- `module-structure` — consuming `dotfilesLib` from modules without cross-tree imports.
- `theme-structure` — palette ownership and Python palette mirror.

## Local hazards

- Modules should use `dotfilesLib.<name>` instead of climbing with `../../` imports.
- `pkgs.nix` owns nixpkgs import helpers; host-specific nixpkgs config is passed through `getPkgsWithConfig`.
- `theme-palette.nix` and `scripts/src/flake_scripts/lib/palette.py` must stay in sync.
- Paths under `data/agents/**` belong in `default.nix`, not in the modules. Take the store form from `agentSkillsDir` / `agentsDataDir`, or the live checkout form from `agentDataFiles <flakeRoot>`. Store paths need a switch to pick up an edit; live paths do not.
- `host-status.nix` repeats `data/agents/skills/local` as a shell literal. It runs against `$FLAKE` at runtime, not an eval-time path, so it cannot use the helpers above.
