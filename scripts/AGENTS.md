# SCRIPTS

Bash helpers (`shell/`) sourced by Justfile recipes; Python package (`src/flake_scripts/`) wired as `uv` console scripts.

## Bash (`shell/`)

`common.sh` is sourced by every shell recipe. Use its helpers — don't reimplement:

```bash
source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

flake_root              # echoes flake path ($FLAKE or default)
get_host [arg]          # arg → .flake-host → hostname detection → prompt
is_darwin               # exit 0 on macOS
nh_prefix               # "nh os" or "nh darwin"
build_nh_cmd <action>   # switch|build|boot|dry|dev → platform-correct nh invocation
confirm "msg"           # y/N prompt, exit 0 on yes
command_exists <bin>
print_success/pending/error/info "msg"
print_header "TITLE"
```

Theme vars (`THEME_*`, `ICON_*`) come from Justfile env when invoked via `just`; `common.sh` falls back to inline ANSI when sourced directly.

## Python (`src/flake_scripts/`)

uv + Hatch project. Entry points wired in `pyproject.toml` `[project.scripts]`:

```bash
uv run --project scripts <entry-point> [args]
```

Adding a new entry point: add `name = "module.path:main"` to `[project.scripts]`, write the `main()` function, then call from Justfile via `uv run --project scripts <name>`.

`lib/`:
- `common.py` — flake paths, Rich consoles
- `palette.py` — **hex mirror of `lib/theme-palette.nix`**; update both when changing colors

`zen/` — Zen browser session extraction → flake config (`zen-session` entry point).

## Gotchas

- **`palette.py` ↔ `theme.nix`** — manual sync; don't change colors in only one
- **Flakes only see tracked files** — `git add` new scripts before `just build-dry`
- **Shell helpers are bash-only** — `set -euo pipefail` is the default; use `[[ ]]` not `[ ]`
