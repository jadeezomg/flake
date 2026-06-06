# Flake scripts

## Layout

| Path | Purpose |
|------|---------|
| **`shell/`** | Bash helpers (`common.sh`). |
| **HM `home/shared/utils/television/`** | Cable TOMLs under `cable/` (like navi `cheats/`); `default.nix` symlinks into `~/.config/television/cable/`. Root `Justfile` `default` runs `tv … just-recipes`. |
| **`pyproject.toml`** | uv / Hatch project **`flake-scripts`** (console scripts below). |
| **`src/flake_scripts/`** | Python package. |
| **`lib/`** | `common.py` (flake paths, Rich consoles), `palette.py` (hex mirror of `home/shared/assets/theme/theme.nix`). |
| **`zen/`** | Zen browser → flake: `zen_session.py` (CLI entry), `extract_pinned_tabs.py`, `sync_flake_profiles.py`. |
| Package root | `symlinks.py`, `read_defaults.py` (other entry points). |

## Commands

From the flake root, with **`uv`** on `PATH`:

```bash
uv run --project scripts symlink-check all
uv run --project scripts zen-session extract --nix
```

The root **`Justfile`** `default` recipe runs `tv` with the `just-recipes` cable; other recipes use `scripts/shell/common.sh`.

## Justfile integration

Root `Justfile` sets `script-interpreter` for uv-backed recipes; see recipe docs there for `zen-sync`, `_read-defaults`, etc.
