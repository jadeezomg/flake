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
- `agent-skills.nix` builds HM skill install attrs from `skills-mattpocock`, `skills-ponytail`, and `data/agents/skills/local/`.
- `mcp-servers.nix` owns live shared MCP registration only. Removals for dropped non-nixpkgs packages belong with that package's retirement plan, not a standing obsolete-cleanup list.
