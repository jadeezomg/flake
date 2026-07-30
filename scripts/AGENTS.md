# SCRIPTS

## Purpose

Shell helpers sourced by Justfile recipes and Python automation exposed through `uv` entry points.

## Use skills

- `flake-structure` — script placement, Justfile integration, and Python entry points.
- `theme-structure` — palette mirror updates for Python/Rich output.

## Local hazards

- Shell recipes should reuse `scripts/shell/common.sh` helpers instead of reimplementing host/platform/logging logic.
- Python automation runs through `uv run --project scripts <entry-point>`; never use bare `python` for project scripts.
- Add Python entry points in `scripts/pyproject.toml` before calling them from Justfile.
- `palette.py` mirrors `lib/theme-palette.nix`; update both together.
- New scripts must be staged before Nix eval/build.
- macOS defaults are hand-written only: declare them as `targets.darwin.defaults."<domain>" = { ... }` in a normal module (see `modules/profiles/work/darwin/brew-casks/*.nix`). There is no generator; the former `darwin-defaults` script and its `defaults.generated.nix` outputs were removed.
