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
- `darwin-defaults` owns two generated files; do not hand-edit either:
  - `modules/profiles/minimal/darwin/defaults.generated.nix` — Apple/System Settings domains from the `APPLE_DOMAINS` allowlist in `darwin_defaults.py`.
  - `modules/profiles/work/darwin/brew-casks/defaults.generated.nix` — Homebrew cask app domains, discovered from the live cask list.
- To configure a domain by hand instead, write it as `targets.darwin.defaults."<domain>" = { ... }` in a normal module; `darwin-defaults` detects that form and stops generating that domain. A domain nested inside a `targets.darwin.defaults = { ... }` block is **not** detected and will be double-declared.
- Read `defaults export`, never `plutil -convert json`: one `<data>`/`<date>` value anywhere in a domain fails the whole JSON conversion and silently drops every key in it.
- Keys matching `_SECRET_KEY_PATTERNS` are always dropped, including under `--include-state-keys`, because both files are committed.
