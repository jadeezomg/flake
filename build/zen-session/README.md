# Zen session scripts

Scripts live in **build/zen-session/** (entry point `zen_session.py` at project root; Python modules in **src/**). They read from your Zen profile and **sync** writes to **home/shared/apps/browsers/zen/profiles/<name>/** (spaces.nix, pins.nix). Profile is chosen by host: **Darwin → caya**, **NixOS/Linux → default**.

## Run from flake root

Use `--project` so uv installs deps (e.g. lz4) from `build/zen-session/pyproject.toml`:

```bash
cd /path/to/flake
uv run --project build/zen-session build/zen-session/zen_session.py [--profile DIR] <command> [options]
```

Example: `uv run --project build/zen-session build/zen-session/zen_session.py sync`

Or run from this directory (no `--project` needed):

```bash
cd build/zen-session
uv sync
uv run zen_session.py sync
```

## Commands

- **extract** — Pinned tabs per workspace (JSON or `--nix` snippet). Options: `--nix`, `--dump-tab-sample`.
- **sync** — Update `home/.../zen/profiles/<caya|default>/spaces.nix` and `pins.nix` from live session (darwin → caya, NixOS → default). Dated backups kept.
- **dump** — Dump window session JSON. Options: `--full`, `--tabs N`.
- **check-spaces** — Show spaces in zen-sessions and window session.

Override Zen profile (input): `--profile DIR` or `ZEN_PROFILE_ROOT=/path`.  
Override output profile name: `ZEN_OUTPUT_PROFILE=caya` or `ZEN_OUTPUT_PROFILE=default`.

## Zen profile paths (input)

- **macOS:** `~/Library/Application Support/zen/Profiles/default`
- **Linux/NixOS:** `~/.config/zen` (or `$XDG_CONFIG_HOME/zen`)
- **Linux (Flatpak):** `~/.var/app/app.zen_browser.zen/zen` — set `ZEN_PROFILE_ROOT` or use `--profile`

## Data sources

- **Spaces:** zen-sessions.jsonlz4 (root `.spaces`).
- **Windows/tabs/folders:** recovery.jsonlz4 or sessionstore.jsonlz4 (first that has `windows`).
- Optional **space_names.json** in profile dir overrides space names/icons.

## Profiles (output)

- **profiles/caya/** — Used on Darwin. base.nix, spaces.nix, pins.nix. Sync overwrites spaces.nix and pins.nix.
- **profiles/default/** — Used on NixOS/Linux. default.nix, spaces.nix, pins.nix. Sync overwrites spaces.nix and pins.nix.

The Nix config (`home/shared/apps/browsers/zen/default.nix`) already selects profile by host: `pkgs.stdenv.isLinux` → default, else caya.
