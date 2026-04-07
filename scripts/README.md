# Flake tooling

- **`Justfile`** (repo root) — [`[doc('…')]`](https://just.systems/man/en/documentation-comments.html) + [`[group('…')]`](https://just.systems/man/en/groups.html).
- **Chooser** — Stock [`just --choose`](https://just.systems/man/en/selecting-recipes-to-run-with-an-interactive-chooser.html) only receives recipe names on stdin, so it can’t show groups/docs. **`default`** runs **`build/just-choose.bash`**: parses **`just --list`**, then **fzf** shows `[group]  recipe  —  doc`. To use the same chooser for plain **`just --choose`**, set **`JUST_CHOOSER`** to that script (absolute path).
- **`build/flake-recipes.bash`** — `build`, `switch`, `generation`, `gc`, `fmt`, `backups`, `init`, `rollback`, `health`, `git`, `setup-age-darwin`, `check-zen`.
- **`build/common.sh`** / **`theme.sh`** — sourced by bash recipes and `flake-recipes.bash`.

## Python ([uv + just `[script]`](https://just.systems/man/en/python-recipes-with-uv.html))

The Justfile sets `script-interpreter := ['uv', 'run', '--script']` for **`check-packages`** and private **`_read-defaults`**. **`read-defaults`** (chooser) prompts for a domain; full CLI: `flake read-defaults <domain> --only-changed …`.

Install **`uv`** on your PATH.

## Usage

- **`flake`** / **`just`** — no args → `just --choose` (fzf).
- **Chooser**: discrete recipes (`build-dry`, `gc-all`, `generation-list`, …). **`init`** / **`read-defaults`** prompt when run alone.
- **CLI with flags** (same as before): `flake build --dry`, `flake switch --fast`, `flake generation switch 3`, `flake read-defaults com.apple.dock --filter-system` — the **`flake`** shell function forwards extra args to private **`_*`** recipes.

## Legacy

**`nuflake`** → `build/flake.nu`. **`build/*.nu`** unchanged.
