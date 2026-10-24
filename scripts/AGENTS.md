# SCRIPTS

## Purpose

Shell helpers sourced by Justfile recipes and Python automation exposed through `uv` entry points.

## Use skills

- `flake-structure`: script placement, Justfile integration, and Python entry points.
- `theme-structure`: palette mirror updates for Python/Rich output.

## Local hazards

- Shell recipes must reuse `scripts/shell/common.sh` helpers instead of reimplementing host/platform/logging logic.
- Python automation runs through `uv run --project scripts <entry-point>`. Never use bare `python` for project scripts.
- Add Python entry points in `scripts/pyproject.toml` before calling them from Justfile.
- `palette.py` mirrors `lib/theme-palette.nix`. Update both together.
- New scripts must be staged before Nix eval/build.
- macOS defaults are hand-written: declare them as `targets.darwin.defaults."<domain>" = { ... }` in a normal module (see `modules/profiles/work/darwin/brew-casks/*.nix`). There is no generic generator. The former `darwin-defaults` script and its `defaults.generated.nix` outputs were removed.
- The one exception is `vorssaint-sync`. It writes only `brew-casks/data/vorssaint.nix` from the live `com.vorssaint.utils` domain. Its state-key deny list mirrors `SettingsBackupSupport.machineStateKeys` in the Vorssaint source. If a Vorssaint update adds state keys, add them to the list.
