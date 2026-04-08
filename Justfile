# Flake — chooser-friendly recipes; CLI args via private _* or `flake <cmd> …`.
# Docs: https://just.systems/man/en/documentation-comments.html
# Groups: https://just.systems/man/en/groups.html
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set unstable := true
set script-interpreter := ['uv', 'run', '--script']

export FLAKE := justfile_directory()
export JUSTFILE := FLAKE + "/Justfile"
export NH_FLAKE := FLAKE

export THEME_GREEN := `printf '\033[32m'`
export THEME_GREEN_BOLD := `printf '\033[1;32m'`
export THEME_YELLOW := `printf '\033[33m'`
export THEME_YELLOW_BOLD := `printf '\033[1;33m'`
export THEME_RED := `printf '\033[31m'`
export THEME_RED_BOLD := `printf '\033[1;31m'`
export THEME_CYAN := `printf '\033[36m'`
export THEME_CYAN_BOLD := `printf '\033[1;36m'`
export THEME_RESET := `printf '\033[0m'`
export ICON_SUCCESS := THEME_GREEN + "▲" + THEME_RESET
export ICON_PENDING := THEME_YELLOW + "❖" + THEME_RESET
export ICON_ERROR := THEME_RED + "▼" + THEME_RESET
export ICON_INFO := THEME_CYAN + "▪" + THEME_RESET

[doc('Interactive picker: fzf with group + doc (see scripts/just-choose.bash)')]
default:
    @bash "$FLAKE/scripts/just-choose.bash"

[group('build')]
[doc('Build / home-manager build for .flake-host')]
build:
    @bash "$FLAKE/scripts/flake-recipes.bash" build --build

[group('build')]
[doc('Stage generation for next boot (nh boot)')]
build-boot:
    @bash "$FLAKE/scripts/flake-recipes.bash" build --boot

[group('build')]
[doc('Dry-run eval/build (no switch)')]
build-dry:
    @bash "$FLAKE/scripts/flake-recipes.bash" build --dry

[group('build')]
[doc('Build with extra trace (dev / debug)')]
build-dev:
    @bash "$FLAKE/scripts/flake-recipes.bash" build --dev

[group('switch')]
[doc('flake check + nh switch (full path)')]
switch:
    @bash "$FLAKE/scripts/flake-recipes.bash" switch

[group('switch')]
[doc('nh switch only; skip flake check and pre-commit git step')]
switch-fast:
    @bash "$FLAKE/scripts/flake-recipes.bash" switch --fast

[group('switch')]
[doc('nix flake check only (no switch)')]
switch-check:
    @bash "$FLAKE/scripts/flake-recipes.bash" switch --check

[group('generations')]
[doc('List system generations (nh os info / darwin-rebuild)')]
generation-list:
    @bash "$FLAKE/scripts/flake-recipes.bash" generation list

[group('generations')]
[doc('Bootloader / EFI entries (NixOS)')]
generation-bootloader:
    @bash "$FLAKE/scripts/flake-recipes.bash" generation bootloader

[group('generations')]
[doc('Switch to a numbered generation (prompts if omitted)')]
generation-switch:
    @bash "$FLAKE/scripts/flake-recipes.bash" generation switch

[group('generations')]
[doc('Delete a numbered generation (prompts if omitted)')]
generation-delete:
    @bash "$FLAKE/scripts/flake-recipes.bash" generation delete

[group('gc')]
[doc('nh clean keeping last N generations (prompts N, default 5)')]
gc-keep:
    @bash "$FLAKE/scripts/flake-recipes.bash" gc keep

[group('gc')]
[doc('nh clean keeping store paths newer than N days (prompts N, default 7)')]
gc-days:
    @bash "$FLAKE/scripts/flake-recipes.bash" gc days

[group('gc')]
[doc('Aggressive nh clean + empty user Trash')]
gc-all:
    @bash "$FLAKE/scripts/flake-recipes.bash" gc all

[group('format')]
[doc('Alejandra all *.nix under flake (summary line)')]
fmt:
    @bash "$FLAKE/scripts/flake-recipes.bash" fmt
    @cd "$FLAKE" && ruff check scripts
    @cd "$FLAKE" && biome check .

[group('format')]
[doc('Alejandra without changed/unchanged summary (e.g. for git hook)')]
fmt-notree:
    @bash "$FLAKE/scripts/flake-recipes.bash" fmt --no-tree

[group('backups')]
[doc('List *.backup / *.bkp under ~/.config with sizes')]
backups:
    @bash "$FLAKE/scripts/flake-recipes.bash" backups

[group('backups')]
[doc('Delete those backup files')]
backups-clean:
    @bash "$FLAKE/scripts/flake-recipes.bash" backups --clean

[group('backups')]
[doc('Show what backups-clean would remove')]
backups-clean-dry:
    @bash "$FLAKE/scripts/flake-recipes.bash" backups --clean --dry

[group('config')]
[doc('Write .flake-host (prompts; use flake init <host> from shell for no prompt)')]
init:
    @bash "$FLAKE/scripts/flake-recipes.bash" init

[group('config')]
[doc('macOS defaults → Nix-style output (prompts domain; empty = list domains)')]
read-defaults:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$FLAKE"
    read -r -p "Domain (empty = list domains): " d || true
    if [[ -z "${d:-}" ]]; then uv run scripts/read-defaults.py; else uv run scripts/read-defaults.py "$d"; fi

[group('config')]
[doc('Create sops age key under ~/.config/sops/age (Darwin)')]
setup-age-darwin:
    @bash "$FLAKE/scripts/flake-recipes.bash" setup-age-darwin

[group('system')]
[doc('Rollback to previous generation (nh rollback / darwin-rebuild --rollback)')]
rollback:
    @bash "$FLAKE/scripts/flake-recipes.bash" rollback

[group('system')]
[doc('Quick snapshot: git status, disk, nh os info')]
health:
    @bash "$FLAKE/scripts/flake-recipes.bash" health

[group('system')]
[doc('Preview flake inputs update (nh switch --update --dry)')]
update:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/common.sh"
    print_header "UPDATE"
    is_darwin && p="nh darwin" || p="nh os"
    bash -c "$p switch --update --dry"
    print_header "END"

[group('system')]
[doc('Reload user services (niri, swaybg, waybar, mako)')]
reload-services:
    #!/usr/bin/env bash
    systemctl --user daemon-reload
    command -v niri >/dev/null && niri msg action do-screen-transition --delay-ms 800 2>/dev/null || true
    for s in rh-swaybg rh-waybar; do systemctl --user restart "${s}.service" 2>/dev/null || true; done
    command -v makoctl >/dev/null && makoctl reload 2>/dev/null || true

[group('repo')]
[doc('Quiet fmt, git status/log, then commit+push (prompts message)')]
git:
    @bash "$FLAKE/scripts/flake-recipes.bash" git

[group('check')]
[doc('Scan flake for broken or missing package references')]
[script]
check-packages:
    # /// script
    # requires-python = ">=3.10"
    # dependencies = []
    # ///
    import os
    import runpy
    import sys

    os.chdir(os.environ["FLAKE"])
    sys.argv = ["check-packages-impl"]
    runpy.run_path("scripts/check-packages-impl.py", run_name="__main__")

[group('check')]
[doc('Verify Zen profile places.sqlite exists')]
check-zen-essentials:
    @bash "$FLAKE/scripts/flake-recipes.bash" check-zen

[positional-arguments]
[group('zen')]
[doc('Zen session CLI; after sync, runs nix fmt on the flake')]
zen-session *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${FLAKE:?}"
    uv run --project scripts/zen-session scripts/zen-session/zen_session.py "$@"
    for a in "$@"; do
      if [[ "$a" == sync ]]; then
        nix fmt .
        break
      fi
    done

[group('zen')]
[doc('Write spaces.nix + pins.nix from live Zen; then nix fmt (see scripts/zen-session/README)')]
zen-sync:
    @cd "$FLAKE" && uv run --project scripts/zen-session scripts/zen-session/zen_session.py sync && nix fmt .

[group('zen')]
[doc('Diff flake spaces/pins vs live Zen session (exit 0 = match)')]
zen-compare:
    @cd "$FLAKE" && uv run --project scripts/zen-session scripts/zen-session/zen_session.py compare

[group('zen')]
[doc('Pinned tabs per workspace (JSON); add --nix for snippet')]
zen-extract *ARGS:
    @cd "$FLAKE" && uv run --project scripts/zen-session scripts/zen-session/zen_session.py extract {{ARGS}}

[group('meta')]
[doc('List all recipes (file order within groups)')]
list:
    @just --justfile "$JUSTFILE" --list --unsorted

[group('meta')]
[doc('nix flake metadata for this repo')]
info:
    #!/usr/bin/env bash
    source "$FLAKE/scripts/common.sh"
    print_header "FLAKE INFO"
    nix flake metadata "$FLAKE"

[private]
[doc]
_build *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" build {{ARGS}}

[private]
[doc]
_switch *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" switch {{ARGS}}

[private]
[doc]
_generation *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" generation {{ARGS}}

[private]
[doc]
_gc *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" gc {{ARGS}}

[private]
[doc]
_fmt *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" fmt {{ARGS}}

[private]
[doc]
_backups *ARGS:
    @bash "$FLAKE/scripts/flake-recipes.bash" backups {{ARGS}}

[private]
[doc]
_init *HOST:
    @bash "$FLAKE/scripts/flake-recipes.bash" init {{HOST}}

[private]
[doc]
_read-defaults *ARGS:
    # /// script
    # requires-python = ">=3.10"
    # dependencies = []
    # ///
    import os
    import runpy
    import shlex
    import sys

    os.chdir(os.environ["FLAKE"])
    _raw = """{{ARGS}}"""
    _extra = shlex.split(_raw.strip()) if _raw.strip() else []
    sys.argv = ["read-defaults", *_extra]
    runpy.run_path("scripts/read-defaults.py", run_name="__main__")
