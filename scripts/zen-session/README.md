# Zen session scripts

Entry point: `scripts/zen-session/zen_session.py` (helpers in `scripts/zen-session/src/`). They read the **Zen browser profile** on disk and can **sync** `spaces.nix` / `pins.nix` into `home/shared/apps/browsers/zen/profiles/<name>/`.

## Run from flake root

```bash
cd /path/to/flake
uv run --project scripts/zen-session scripts/zen-session/zen_session.py [--profile DIR] <command> [options]
```

Example: `uv run --project scripts/zen-session scripts/zen-session/zen_session.py sync`

From the flake root you can use **just** (same `uv` project): `just zen-sync`, `just zen-compare`, `just zen-extract --nix`, or `just zen-session dump --tabs 5` (see `just --list`, group **zen**). The `just` recipes **`zen-sync`** and **`zen-session … sync`** run **`nix fmt .`** afterward so edited `.nix` files match the flake formatter.

Or from this directory:

```bash
cd scripts/zen-session
uv sync
uv run zen_session.py sync
```

## Commands

- **extract** — Pinned tabs per workspace (JSON or `--nix` snippet). Options: `--nix`, `--dump-tab-sample`.
- **sync** — Write `spaces.nix` and `pins.nix` for the selected **flake profile directory** (see below). Dated `.bak` backups next to the files.
- **compare** — Compare on-disk `spaces.nix` / `pins.nix` to the current browser session. Exit `0` if match, `1` if differ.
- **dump** — Dump window session JSON. Options: `--full`, `--tabs N`.
- **check-spaces** — Show where space names appear in session files.

## Environment

| Variable | Role |
|----------|------|
| `ZEN_PROFILE_ROOT` | Zen **browser** profile directory (input). Overridden by `--profile` / `-p`. |
| `ZEN_OUTPUT_PROFILE` | Flake **output** subdirectory name under `zen/profiles/` (e.g. `default`, `caya`). |
| `ZEN_IGNORE_OUTPUT_PROFILE_NIXOS_GUARD` | On NixOS, set to `1`/`true`/`yes` to allow `ZEN_OUTPUT_PROFILE` to select the **alternate** flake profile when it would otherwise be remapped to `default`. |
| `ZEN_SYNC_CAYA_ON_NIXOS` | Deprecated alias for `ZEN_IGNORE_OUTPUT_PROFILE_NIXOS_GUARD`. |

If `ZEN_OUTPUT_PROFILE` is unset, the sync target defaults to **`caya` on macOS** and **`default` on other platforms** (matching `home/shared/apps/browsers/zen/default.nix`). On NixOS, if `ZEN_OUTPUT_PROFILE` is the alternate profile name (`caya`), it is remapped to `default` unless one of the guard variables above is set—so a shared shell exporting `ZEN_OUTPUT_PROFILE=caya` does not overwrite the wrong bundle.

## Zen profile paths (browser input)

- **macOS:** `~/Library/Application Support/zen/Profiles/default`
- **Linux:** `$XDG_CONFIG_HOME/zen/default` (with a NixOS-only scan of sibling dirs under `$XDG_CONFIG_HOME/zen/` if `default` has no `zen-sessions.jsonlz4`)
- **Flatpak:** `~/.var/app/app.zen_browser.zen/zen` — set `ZEN_PROFILE_ROOT` or `--profile`

## Data sources

- **Spaces:** `zen-sessions.jsonlz4` (root `.spaces`).
- **Windows/tabs/folders:** `recovery.jsonlz4` or `sessionstore.jsonlz4` (first with `windows`).
- Optional **space_names.json** in the browser profile overrides space names/icons.

## Flake layout (output)

- **profiles/default/** — Primary bundle for Linux in this flake.
- **profiles/caya/** — Alternate bundle (used for non-Linux in `zen/default.nix`).

Sync overwrites only `spaces.nix` and `pins.nix` in the chosen directory.

Implementation: `src/sync_flake_profiles.py` (sync/compare), `src/extract_pinned_tabs.py` (session parsing).
