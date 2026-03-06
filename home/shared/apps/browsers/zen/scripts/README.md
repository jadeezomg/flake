# Zen browser scripts

All scripts share the same config: **profile path** and **session file order** are defined in `extract_pinned_tabs.py` (and `ZEN_PROFILE_ROOT` / `SESSION_PATHS`). Use one entry point or run scripts individually.

## Wrapper (single entry point)

```bash
uv run zen_session.py [--profile DIR] <command> [options]
```

- **--profile / -p** — Override Zen profile directory (else `ZEN_PROFILE_ROOT` or default macOS path).
- **extract** — Extract pinned tabs per workspace. Options: `--nix`, `--dump-tab-sample`.
- **sync** — Update `profiles/caya/spaces.nix`, `essentials.nix`, `pins.nix` from the live session.
- **dump** — Dump raw session JSON. Options: `--full`, `--tabs N`.
- **check-spaces** — Show where space names appear in session files.

Examples:

```bash
uv run zen_session.py --profile ~/Library/Application\ Support/zen/Profiles/default extract --nix
uv run zen_session.py sync
uv run zen_session.py dump --full --tabs 5
uv run zen_session.py check-spaces
```

## Individual scripts (same config)

Profile path (macOS default): `~/Library/Application Support/zen/Profiles/default`. Override: `ZEN_PROFILE_ROOT=/path uv run ...` or `zen_session.py --profile /path <cmd>`.

| Script | Purpose |
|--------|---------|
| `extract_pinned_tabs.py` | Extract pinned tabs per workspace; `--nix` prints Nix snippet, `--dump-tab-sample` debugs tab structure. |
| `sync_caya_from_session.py` | Write `profiles/caya/spaces.nix`, `essentials.nix`, `pins.nix` from live session (dated backups kept). |
| `dump_session.py` | Print raw session structure; `--full` writes `session_dump.json`, `--tabs N` controls sample size. |
| `check_spaces.py` | Print which session files and keys contain space names (top-level, sidebar, window.spaces). |

Session file order: we load a session that has `windows` first (`sessionstore.jsonlz4` → `recovery.jsonlz4`), then merge space **names/icons** from `zen-sessions.jsonlz4` (its root is the sidebar object with `spaces`: uuid, name, icon, position). See `SESSION_PATHS` and merge in `extract_pinned_tabs.py`.

## Space names and icons

Session files like `recovery.jsonlz4` often don’t contain space names; **`zen-sessions.jsonlz4`** (and `sidebar.spaces`) does when present. The extractor also merges from `zen-sessions-backup/clean.jsonlz4` and the latest `zen-sessions-backup/zen-sessions-*.jsonlz4`. If spaces still show as "Default", add a **space names file**:

- Default path: `<profile>/space_names.json`.
- Override: `ZEN_SPACE_NAMES_FILE=/path/to/space_names.json`.

Format: JSON object mapping space ID (UUID) to a name string or `{ "name": "…", "icon": "", "position": 0 }`.

## Caya profile layout

`profiles/caya/` is split into **base.nix** (settings, extensions, containers), **spaces.nix** (workspaces), **essentials.nix** (pins in all workspaces), and **pins.nix** (per-workspace pins with `spaceId`). `default.nix` merges essentials and pins and sets `isEssential` accordingly.

**Zen folder format:** `window.folders` has metadata (`id`, `name`, `parentId`, …); tabs reference folder via **`groupId`**. See zen-browser/desktop `src/zen/folders/ZenFolders.mjs` and `ZenSessionManager.sys.mjs`.
