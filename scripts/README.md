# Flake scripts

## Layout

| Path | Purpose |
|------|---------|
| **`shell/`** | Bash helpers (`common.sh`). |
| **HM `modules/profiles/essentials/utils/television/`** | Cable TOMLs under `cable/` (like navi `cheats/`). `default.nix` symlinks into `~/.config/television/cable/`. Root `Justfile` `default` runs `tv … just-recipes`. |
| **`pyproject.toml`** | uv / Hatch project **`flake-scripts`** (console scripts below). |
| **`src/flake_scripts/`** | Python package. |
| **`lib/`** | `common.py` (flake paths, Rich consoles), `palette.py` (hex mirror of `lib/theme-palette.nix`). |
| **`zen/`** | Zen browser → flake: `session.py` (MozLZ4 reader), `sync.py` (`zen-sync` CLI). |
| **`vorssaint_sync.py`** | Vorssaint → flake: `vorssaint-sync` CLI, writes `modules/profiles/work/darwin/brew-casks/data/vorssaint.nix`. |
| Package root | `symlinks.py`, `update_packages.py`, `media_quality.py` (other entry points). |

## Commands

From the flake root, with **`uv`** on `PATH`:

```bash
uv run --project scripts symlink-check all
uv run --project scripts zen-sync --check
uv run --project scripts vorssaint-sync --check
```

The root **`Justfile`** `default` recipe runs `tv` with the `just-recipes` cable. Other recipes use `scripts/shell/common.sh`.

## Vorssaint settings

You change Vorssaint settings in the app, and then you copy them into the flake:

1. Change the settings in the Vorssaint window on the Mac.
2. Run `just vorssaint-sync`. The script reads the live `com.vorssaint.utils` defaults domain and writes `data/vorssaint.nix`.
3. Read the diff, then commit the file.

The script leaves out app state, such as onboarding markers, migration flags, window sizes and per-display caches. It also leaves out data and date values, because `targets.darwin.defaults` cannot write them. It shows a warning for each value that it leaves out. Run `just vorssaint-check` to compare the flake with the live app without a write. If they differ, the check exits with 1.

If you remove a key from the data file, the live app keeps its value. The next sync then adds the key again. To remove a setting, change it in the app.

## Justfile integration

Root `Justfile` sets `script-interpreter` for uv-backed recipes. See the recipe docs there for `zen-sync`, `zen-check`, `vorssaint-sync`, `vorssaint-check`, `symlink-check` and the other recipes.
