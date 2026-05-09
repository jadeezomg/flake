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


[doc('Interactive picker: fzf with group + doc (see scripts/shell/just-choose.bash)')]
default:
    @bash "$FLAKE/scripts/shell/just-choose.bash"


[doc('Build / home-manager build for .flake-host')]
[group('build')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build '${FLAKE}#${h}'" || sc="nh os build '${FLAKE}#${h}'"
    notify "Flake Build" "Building $h..." "pending"
    print_info "-> $sc"; bash -c "$sc"
    notify "Flake Build" "OK" "success"; print_header "END"

[doc('Stage generation for next boot (nh boot)')]
[group('build')]
build-boot:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build '${FLAKE}#${h}'" || sc="nh os boot '${FLAKE}#${h}'"
    notify "Flake Build" "Boot $h..." "pending"
    print_info "-> $sc"; bash -c "$sc"
    notify "Flake Build" "Next reboot" "success"; print_header "END"

[doc('Dry-run eval/build (no switch)')]
[group('build')]
build-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build --dry '${FLAKE}#${h}'" || sc="nh os test '${FLAKE}#${h}'"
    notify "Flake Build" "Dry $h..." "pending"
    print_info "-> $sc"; bash -c "$sc"; print_header "END"

[doc('Build with extra trace (dev / debug)')]
[group('build')]
build-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin switch --show-trace '${FLAKE}#${h}'" || sc="nh os switch --show-trace '${FLAKE}#${h}'"
    notify "Flake Build" "Trace $h..." "pending"
    print_info "-> $sc"; bash -c "$sc"; print_header "END"


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
    is_darwin && sc="nh darwin switch '${FLAKE}#${h}'" || sc="nh os switch '${FLAKE}#${h}'"
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "-> $sc"; bash -lc "$sc"; echo ""
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
    is_darwin && sc="nh darwin switch '${FLAKE}#${h}'" || sc="nh os switch '${FLAKE}#${h}'"
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "-> $sc"; bash -lc "$sc"; print_header "END"

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


alias gc := gc-keep

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


[doc('Format all .nix/scripts/js/ts/json and type-check scripts')]
[group('format')]
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "FMT"
    print_pending "alejandra  formatting .nix files..."
    alejandra --quiet "$FLAKE" 2>&1 | tail -n +2 || { print_error "alejandra  failed"; exit 1; }
    print_success "alejandra  done"
    echo
    print_pending "deadnix    removing unused bindings..."
    deadnix --edit "$FLAKE"
    print_success "deadnix    done"
    echo
    print_pending "ruff       formatting scripts..."
    ruff format "$FLAKE/scripts"
    print_success "ruff       done"
    echo
    print_pending "ty         type-checking scripts..."
    uv run --project "$FLAKE/scripts" ty check "$FLAKE/scripts/src"
    print_success "ty         done"
    echo
    print_pending "biome      formatting js/ts/json..."
    cd "$FLAKE" && biome format --write .
    print_success "biome      done"
    print_header "END"

[doc('Lint .nix files for unused bindings (deadnix) and antipatterns (statix)')]
[group('format')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "LINT"
    deadnix "$FLAKE"
    statix check "$FLAKE"
    print_header "END"

[doc('Alejandra without banner output (e.g. for git hook)')]
[group('format')]
fmt-notree:
    @alejandra --quiet "$FLAKE" >/dev/null


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
      if [[ -n "$prev" && "$prev" != "$t" ]] && ! confirm "Overwrite $prev -> $t?"; then
        print_info "Unchanged."; exit 0
      fi
    fi
    set_host "$t"; print_header "END"

[doc('macOS defaults -> Nix-style output (prompts domain; empty = list domains)')]
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

[doc('Post-switch: Context7 CLI skills (Claude, Cursor, OpenCode); needs ctx7 login or CONTEXT7_API_KEY')]
[group('config')]
post-install:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "$FLAKE/scripts/shell/post-install.bash"


[doc('Rollback to previous generation (nh rollback / darwin-rebuild --rollback)')]
[group('system')]
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "ROLLBACK"
    if is_darwin; then darwin-rebuild switch --rollback; else nh os rollback; fi
    print_header "END"

[doc('Quick snapshot: Host Status, git status, disk, nh os info')]
[group('system')]
health:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "HEALTH"
    command -v host-status >/dev/null && host-status all || true
    git -C "$FLAKE" status --short 2>/dev/null | head -5
    df -h / 2>/dev/null | head -2
    is_darwin || nh os info 2>/dev/null | head -15
    print_header "END"

[doc('Full external refresh: update-packages (packages/*/update.json, which includes nix-update entries), flake.lock, optional fwupdmgr; then just fmt. Set UPDATE_FORCE=1 for update-packages --force')]
[group('system')]
update:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "UPDATE"
    print_pending "update-packages  updating custom flake packages..."
    up=()
    [[ "${UPDATE_FORCE:-}" == 1 ]] && up+=(--force)
    uv run --project "$FLAKE/scripts" update-packages "${up[@]}"
    print_success "update-packages  done"
    print_pending "nix              updating flake.lock..."
    nix flake update --flake "$FLAKE"
    print_success "nix              flake.lock updated"
    print_pending "fmt              formatting..."
    just --justfile "${JUSTFILE:?}" fmt
    print_success "fmt              done"
    h="$(get_host "")"
    if ! is_darwin && [[ "$h" == framework ]] && command -v fwupdmgr >/dev/null; then
      print_pending "fwupdmgr         checking BIOS/firmware updates (framework)..."
      fwupdmgr refresh --force >/dev/null 2>&1 || true
      fwupdmgr get-updates || true
      print_success "fwupdmgr         check complete"
    fi
    print_header "END"


[doc('Quiet fmt, git status/log, then commit+push (prompts message)')]
[group('repo')]
git:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    [[ -d "$FLAKE/.git" ]] || exit 1
    alejandra --quiet "$FLAKE" >/dev/null 2>&1 || true
    git -C "$FLAKE" status -sb; git -C "$FLAKE" log --oneline -n 5
    [[ -z "$(git -C "$FLAKE" status --porcelain)" ]] && exit 0
    read -r -p "Commit: " msg || true
    [[ -z "${msg:-}" || "$msg" == abort ]] && exit 0
    git -C "$FLAKE" add -A && git -C "$FLAKE" commit -m "$msg" && git -C "$FLAKE" push


[doc('Update custom flake packages via scripts/update-packages (reads packages/*/update.json)')]
[group('check')]
update-packages *ARGS:
    @uv run --project "$FLAKE/scripts" update-packages {{ ARGS }}

[doc('Run `nix-update` on one flake package (interactive picker when no attr). For the full batch, use `just update`.')]
[group('check')]
[positional-arguments]
nix-update-pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "${FLAKE:?}"
    if [[ $# -eq 0 ]]; then
      mapfile -t pkg_attrs < <(nix eval --impure --accept-flake-config \
        --expr "builtins.attrNames (builtins.getFlake \"$PWD\").packages.\${builtins.currentSystem}" \
        --json | jq -r '.[]' | sort -u)
      if command -v fzf >/dev/null 2>&1; then
        attr="$(printf '%s\n' "${pkg_attrs[@]}" | fzf --prompt='nix-update> ' --height=40% --preview-window=hidden)"
      else
        echo "attrs: ${pkg_attrs[*]}"
        read -rp "attr: " attr
      fi
      [[ -n "${attr:-}" ]] || exit 0
      set -- "$attr"
    fi
    attr="$1"; shift
    if command -v nix-update >/dev/null 2>&1; then
      nix-update --flake "$@" "$attr"
    else
      nix develop "$FLAKE" --command nix-update --flake "$@" "$attr"
    fi
    just --justfile "${JUSTFILE:?}" fmt

[doc('DMS / niri / quickshell symlink report (uv symlink-check all)')]
[group('check')]
symlink-check:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" symlink-check all

[doc('Strict: DMS settings.json must symlink into flake (uv symlink-check dms-settings)')]
[group('check')]
symlink-check-dms:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" symlink-check dms-settings


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


[doc('Start declarative Unsloth Studio user service')]
[group('llm')]
unsloth:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    print_header "UNSLOTH"
    print_info "-> systemctl --user start unsloth-studio.service"
    systemctl --user start unsloth-studio.service
    print_success "Unsloth Studio start requested"
    print_header "END"

[doc('Stop Unsloth Studio user service')]
[group('llm')]
unsloth-stop:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user stop unsloth-studio.service
    echo "unsloth-studio service stopped"

[doc('Delete Unsloth Studio container state (keeps mounted workdir)')]
[group('llm')]
unsloth-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user stop unsloth-studio.service >/dev/null 2>&1 || true
    podman rm -f unsloth-studio >/dev/null 2>&1 || true
    echo "unsloth-studio container removed"

[doc('Diff data/agents/skills/ vs ~/Git/skills (nested structure); interactive apply. Pass --apply-all to skip prompts.')]
[group('llm')]
[positional-arguments]
skills-upstream *ARGS:
    @bash "$FLAKE/scripts/shell/skills-upstream.bash" "$@"

[doc('Tail logs from Unsloth Studio user service')]
[group('llm')]
unsloth-logs:
    #!/usr/bin/env bash
    set -euo pipefail
    journalctl --user -u unsloth-studio.service -f

[doc('Show status of Unsloth Studio user service')]
[group('llm')]
unsloth-status:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user status unsloth-studio.service


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
