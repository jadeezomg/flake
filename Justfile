# Flake — chooser-friendly recipes; CLI args via private _* or `just <cmd> …`.
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

# ── default ───────────────────────────────────────────────────────────────────

[doc('Interactive picker: fzf with group + doc (see scripts/shell/just-choose.bash)')]
default:
    @bash "$FLAKE/scripts/shell/just-choose.bash"

# ── build ─────────────────────────────────────────────────────────────────────

[doc('Build / home-manager build for .flake-host')]
[group('build')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build --flake '${FLAKE}#${h}'" || sc="nh os build --flake '${FLAKE}#${h}'"
    notify "Flake Build" "Building $h..." "pending"
    print_info "→ $sc"; bash -c "$sc"
    notify "Flake Build" "OK" "success"; print_header "END"

[doc('Stage generation for next boot (nh boot)')]
[group('build')]
build-boot:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build --flake '${FLAKE}#${h}'" || sc="nh os boot --flake '${FLAKE}#${h}'"
    notify "Flake Build" "Boot $h..." "pending"
    print_info "→ $sc"; bash -c "$sc"
    notify "Flake Build" "Next reboot" "success"; print_header "END"

[doc('Dry-run eval/build (no switch)')]
[group('build')]
build-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build --dry-run --flake '${FLAKE}#${h}'" || sc="nh os test --flake '${FLAKE}#${h}'"
    notify "Flake Build" "Dry $h..." "pending"
    print_info "→ $sc"; bash -c "$sc"; print_header "END"

[doc('Build with extra trace (dev / debug)')]
[group('build')]
build-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin switch --show-trace --flake '${FLAKE}#${h}'" || sc="nh os switch --show-trace --flake '${FLAKE}#${h}'"
    notify "Flake Build" "Trace $h..." "pending"
    print_info "→ $sc"; bash -c "$sc"; print_header "END"

# ── switch ────────────────────────────────────────────────────────────────────

[doc('flake check + nh switch (full path)')]
[group('switch')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "SWITCH"
    command -v just >/dev/null && just --justfile "$JUSTFILE" git || true; echo ""
    notify "Flake Switch" "Pre-flight..." "pending"
    bash -lc "nix flake check --all-systems $FLAKE --no-write-lock-file" \
      && notify "Flake Switch" "OK" "success" \
      || notify "Flake Switch" "Check failed [continue]" "pending"
    echo ""
    h="$(get_host "")"
    is_darwin && sc="nh darwin switch --flake '${FLAKE}#${h}'" || sc="nh os switch --flake '${FLAKE}#${h}'"
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "→ $sc"; bash -lc "$sc"; echo ""
    hm_vars="/etc/profiles/per-user/${USER}/etc/profile.d/hm-session-vars.sh"
    [[ -f "$hm_vars" ]] && bash -lc "source '$hm_vars'" || true
    print_header "END"

[doc('nh switch only; skip flake check and pre-commit git step')]
[group('switch')]
switch-fast:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "SWITCH"
    notify "Flake Switch" "Fast" "info"; echo ""
    h="$(get_host "")"
    is_darwin && sc="nh darwin switch --flake '${FLAKE}#${h}'" || sc="nh os switch --flake '${FLAKE}#${h}'"
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "→ $sc"; bash -lc "$sc"; print_header "END"

[doc('nix flake check only (no switch)')]
[group('switch')]
switch-check:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "SWITCH"
    notify "Flake Switch" "Pre-flight..." "pending"
    bash -lc "nix flake check --all-systems $FLAKE --no-write-lock-file" \
      && notify "Flake Switch" "OK" "success" \
      || notify "Flake Switch" "Check failed" "pending"
    print_header "END"

# ── generations ───────────────────────────────────────────────────────────────

[doc('List system generations (nh os info / darwin-rebuild)')]
[group('generations')]
generation-list:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    if is_darwin; then print_header "DARWIN"; darwin-rebuild --list-generations 2>/dev/null || true
    else print_header "NIXOS"; nh os info; fi
    print_header "END"

[doc('Bootloader / EFI entries (NixOS)')]
[group('generations')]
generation-bootloader:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    is_darwin && { print_error "N/A on Darwin"; exit 0; }
    print_header "BOOTLOADER"
    bootctl list 2>/dev/null || true
    for e in /boot/efi/EFI/Linux /boot/EFI/Linux; do [[ -d "$e" ]] && ls -la "$e"; done
    command -v efibootmgr >/dev/null && efibootmgr -v || true
    print_header "END"

[doc('Switch to a numbered generation (prompts if omitted)')]
[group('generations')]
generation-switch:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    if is_darwin; then print_header "DARWIN"; darwin-rebuild --list-generations 2>/dev/null || true
    else print_header "NIXOS"; nh os info; fi
    echo ""
    num="$(prompt_number "Generation #")" || exit 0
    [[ -z "$num" ]] && exit 0
    if is_darwin; then darwin-rebuild switch --rollback-to "$num"
    else nh os rollback --to "$num"; fi
    print_header "END"

[doc('Delete a numbered generation (prompts if omitted)')]
[group('generations')]
generation-delete:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    if is_darwin; then print_header "DARWIN"; darwin-rebuild --list-generations 2>/dev/null || true
    else print_header "NIXOS"; nh os info; fi
    echo ""
    num="$(prompt_number "Delete #")" || exit 0
    [[ -z "$num" ]] && exit 0
    sudo nix-env --delete-generations "$num" -p /nix/var/nix/profiles/system
    print_header "END"

# ── gc ────────────────────────────────────────────────────────────────────────

[doc('nh clean keeping last N generations (prompts N, default 5)')]
[group('gc')]
gc-keep:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "GC"
    n="$(prompt_number "Keep N [5]")" || n=5
    nh clean all --keep "${n:-5}"
    print_header "END"

[doc('nh clean keeping store paths newer than N days (prompts N, default 7)')]
[group('gc')]
gc-days:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "GC"
    d="$(prompt_number "Days [7]")" || d=7
    nh clean all --keep-since "${d:-7}d"
    print_header "END"

[doc('Aggressive nh clean + empty user Trash')]
[group('gc')]
gc-all:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "GC"
    nh clean all
    tr="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
    [[ -d "$tr" ]] && { rm -rf "$tr" 2>/dev/null || sudo rm -rf "$tr" 2>/dev/null || true; }
    print_header "END"

# ── format ────────────────────────────────────────────────────────────────────

[doc('Alejandra all *.nix under flake (summary line)')]
[group('format')]
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "FMT"
    changed=0 unchanged=0 failed=0
    while IFS= read -r -d '' f; do
      [[ "$(basename "$f")" == default.nix ]] && continue
      mb=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
      if alejandra "$f" >/dev/null 2>&1; then
        ma=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
        [[ "$ma" != "$mb" ]] && changed=$((changed+1)) || unchanged=$((unchanged+1))
      else failed=$((failed+1)); fi
    done < <(find "$FLAKE" -name "*.nix" -type f -print0 2>/dev/null)
    [[ "$failed" -gt 0 ]] && exit 1
    echo "changed:$changed unchanged:$unchanged"
    cd "$FLAKE" && ruff check scripts && biome check .
    print_header "END"

[doc('Alejandra without changed/unchanged summary (e.g. for git hook)')]
[group('format')]
fmt-notree:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r -d '' f; do
      [[ "$(basename "$f")" == default.nix ]] && continue
      alejandra "$f" >/dev/null 2>&1 || exit 1
    done < <(find "$FLAKE" -name "*.nix" -type f -print0 2>/dev/null)

# ── backups ───────────────────────────────────────────────────────────────────

[doc('List *.backup / *.bkp under ~/.config with sizes')]
[group('backups')]
backups:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BACKUPS"
    mapfile -t files < <(find "${HOME}/.config" \( -name "*.backup" -o -name "*.bkp" \) -type f 2>/dev/null)
    [[ ${#files[@]} -eq 0 ]] && print_header "END" && exit 0
    for f in "${files[@]}"; do du -h "$f" 2>/dev/null | awk -v p="$f" '{print $1,p}'; done
    print_header "END"

[doc('Delete those backup files')]
[group('backups')]
backups-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BACKUPS"
    mapfile -t files < <(find "${HOME}/.config" \( -name "*.backup" -o -name "*.bkp" \) -type f 2>/dev/null)
    [[ ${#files[@]} -eq 0 ]] && print_header "END" && exit 0
    for f in "${files[@]}"; do rm -f "$f"; done
    print_header "END"

[doc('Show what backups-clean would remove')]
[group('backups')]
backups-clean-dry:
    @find "${HOME}/.config" \( -name "*.backup" -o -name "*.bkp" \) -type f 2>/dev/null | xargs -r du -h

# ── config ────────────────────────────────────────────────────────────────────

[doc('Write .flake-host (prompts; use just _init <host> for no prompt)')]
[group('config')]
init:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "INIT"
    t="$(detect_host_from_hostname)" || t=""
    read -r -p "Host [${t:-detect}]: " msg || true
    [[ -n "${msg// }" ]] && t="$msg"
    [[ -z "${t// }" ]] && { print_error "Unknown host; run: just _init <hostname>"; exit 1; }
    cf="${FLAKE}/.flake-host"
    if [[ -f "$cf" ]]; then
      prev=$(tr -d '[:space:]' <"$cf" || true)
      if [[ -n "$prev" && "$prev" != "$t" ]] && ! confirm "Overwrite $prev → $t?"; then
        print_info "Unchanged."; exit 0
      fi
    fi
    set_host "$t"; print_header "END"

[doc('macOS defaults → Nix-style output (prompts domain; empty = list domains)')]
[group('config')]
read-defaults:
    #!/usr/bin/env bash
    set -euo pipefail
    read -r -p "Domain (empty = list domains): " d || true
    if [[ -z "${d:-}" ]]; then uv run --project "$FLAKE/scripts" read-defaults
    else uv run --project "$FLAKE/scripts" read-defaults "$d"; fi

[doc('Create sops age key under ~/.config/sops/age (Darwin)')]
[group('config')]
setup-age-darwin:
    #!/usr/bin/env bash
    set -euo pipefail
    kd="${HOME}/.config/sops/age"; kf="$kd/keys.txt"
    mkdir -p "$kd"
    [[ ! -f "$kf" ]] && nix develop "$FLAKE" --command age-keygen -o "$kf"
    nix develop "$FLAKE" --command age-keygen -y "$kf"

# ── system ────────────────────────────────────────────────────────────────────

[doc('Rollback to previous generation (nh rollback / darwin-rebuild --rollback)')]
[group('system')]
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "ROLLBACK"
    if is_darwin; then darwin-rebuild switch --rollback; else nh os rollback; fi
    print_header "END"

[doc('Quick snapshot: git status, disk, nh os info')]
[group('system')]
health:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "HEALTH"
    git -C "$FLAKE" status --short 2>/dev/null | head -5
    df -h / 2>/dev/null | head -2
    is_darwin || nh os info 2>/dev/null | head -15
    print_header "END"

[doc('Preview flake inputs update (nh switch --update --dry)')]
[group('system')]
update:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "UPDATE"
    is_darwin && p="nh darwin" || p="nh os"
    bash -c "$p switch --update --dry"
    print_header "END"

[doc('Reload user services (niri, swaybg, waybar, mako)')]
[group('system')]
reload-services:
    #!/usr/bin/env bash
    systemctl --user daemon-reload
    command -v niri >/dev/null && niri msg action do-screen-transition --delay-ms 800 2>/dev/null || true
    for s in rh-swaybg rh-waybar; do systemctl --user restart "${s}.service" 2>/dev/null || true; done
    command -v makoctl >/dev/null && makoctl reload 2>/dev/null || true

# ── repo ──────────────────────────────────────────────────────────────────────

[doc('Quiet fmt, git status/log, then commit+push (prompts message)')]
[group('repo')]
git:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    [[ -d "$FLAKE/.git" ]] || exit 1
    while IFS= read -r -d '' f; do
      [[ "$(basename "$f")" == default.nix ]] && continue
      alejandra "$f" >/dev/null 2>&1 || true
    done < <(find "$FLAKE" -name "*.nix" -type f -print0 2>/dev/null)
    git -C "$FLAKE" status -sb; git -C "$FLAKE" log --oneline -n 5
    read -r -p "Commit: " msg || true
    [[ -z "${msg:-}" || "$msg" == abort ]] && exit 0
    git -C "$FLAKE" add -A && git -C "$FLAKE" commit -m "$msg" && git -C "$FLAKE" push

# ── check ─────────────────────────────────────────────────────────────────────

[doc('Scan flake for broken or missing package references')]
[group('check')]
check-packages:
    @uv run --project "$FLAKE/scripts" check-packages

[doc('Verify Zen profile places.sqlite exists')]
[group('check')]
check-zen-essentials:
    #!/usr/bin/env bash
    Z="${HOME}/.zen/default"; D="$Z/places.sqlite"
    [[ -d "$Z" && -f "$D" ]] || exit 1
    echo "OK $D"

[doc('DMS / niri / quickshell symlink report (uv symlink-check all)')]
[group('check')]
symlink-check:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" symlink-check all

[doc('Strict: DMS settings.json must symlink into flake (uv symlink-check dms-settings)')]
[group('check')]
symlink-check-dms:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" symlink-check dms-settings

# ── zen ───────────────────────────────────────────────────────────────────────

[doc('Zen session CLI; after sync, runs nix fmt on the flake')]
[group('zen')]
[positional-arguments]
zen-session *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${FLAKE:?}"
    uv run --project "$FLAKE/scripts" zen-session "$@"
    for a in "$@"; do
      if [[ "$a" == sync ]]; then nix fmt .; break; fi
    done

[doc('Write spaces.nix + pins.nix from live Zen; then nix fmt (see scripts/README.md)')]
[group('zen')]
zen-sync:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" zen-session sync && nix fmt .

[doc('Diff flake spaces/pins vs live Zen session (exit 0 = match)')]
[group('zen')]
zen-compare:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" zen-session compare

[doc('Pinned tabs per workspace (JSON); add --nix for snippet')]
[group('zen')]
zen-extract *ARGS:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" zen-session extract {{ ARGS }}

# ── meta ──────────────────────────────────────────────────────────────────────

[doc('List all recipes (file order within groups)')]
[group('meta')]
list:
    @just --justfile "$JUSTFILE" --list --unsorted

[doc('nix flake metadata for this repo')]
[group('meta')]
info:
    #!/usr/bin/env bash
    source "$FLAKE/scripts/shell/common.sh"
    print_header "FLAKE INFO"
    nix flake metadata "$FLAKE"

# ── private ───────────────────────────────────────────────────────────────────

[private]
_init host:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    printf '%s\n' "{{ host }}" > "$FLAKE/.flake-host"
    print_success "Host set to: {{ host }}"

[private]
_read-defaults *ARGS:
    @uv run --project "$FLAKE/scripts" read-defaults {{ ARGS }}
