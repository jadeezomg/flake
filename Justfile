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


[doc('Recipe picker: `tv just-recipes` (cable TOML only). Run a recipe with F5.')]
default:
    tv --cable-dir "$FLAKE/modules/profiles/essentials/utils/television/cable" just-recipes "$FLAKE"


[doc('Build / home-manager build for .flake-host')]
[group('build')]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build '${FLAKE}#${h}'" || sc="nh os build '${FLAKE}#${h}'"
    notify "Flake Build" "Building $h..." "pending"
    print_info "-> $sc"; run_logged "Flake Build" bash -c "$sc"
    notify "Flake Build" "OK" "success"; print_header "END"

[doc('Stage generation for next boot (nh boot)')]
[group('build')]
build-boot:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build '${FLAKE}#${h}'" || sc="nh os boot '${FLAKE}#${h}'"
    notify "Flake Build" "Boot $h..." "pending"
    print_info "-> $sc"; run_logged "Flake Build" bash -c "$sc"
    notify "Flake Build" "Next reboot" "success"; print_header "END"

[doc('Dry-run eval/build (no switch)')]
[group('build')]
build-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin build --dry '${FLAKE}#${h}'" || sc="nh os test '${FLAKE}#${h}'"
    notify "Flake Build" "Dry $h..." "pending"
    print_info "-> $sc"; run_logged "Flake Build" bash -c "$sc"; print_header "END"

[doc('Build with extra trace (dev / debug)')]
[group('build')]
build-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "BUILD"; h="$(get_host "")"
    is_darwin && sc="nh darwin switch --show-trace '${FLAKE}#${h}'" || sc="nh os switch --show-trace '${FLAKE}#${h}'"
    notify "Flake Build" "Trace $h..." "pending"
    print_info "-> $sc"; run_logged "Flake Build" bash -c "$sc"; print_header "END"


[doc('flake check + build, commit on success, then activate; errors land in the clipboard')]
[group('switch')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "SWITCH"
    notify "Flake Switch" "Pre-flight..." "pending"
    bash -lc "nix flake check --all-systems $FLAKE --no-write-lock-file" \
      && notify "Flake Switch" "OK" "success" \
      || notify "Flake Switch" "Check failed [continue]" "pending"
    echo ""
    h="$(get_host "")"
    is_darwin && nhp="nh darwin" || nhp="nh os"
    # 1) Build first — nothing gets committed unless the build succeeds.
    notify "Flake Switch" "Building $h..." "pending"
    print_info "-> $nhp build"
    run_logged "Flake Build" bash -lc "$nhp build '${FLAKE}#${h}'"
    echo ""
    # 2) Tree is known-good: optional commit + push.
    command -v just >/dev/null && just --justfile "$JUSTFILE" git || true; echo ""
    # 3) Activate (everything is cached from step 1).
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "-> $nhp switch"
    run_logged "Flake Switch" bash -lc "$nhp switch '${FLAKE}#${h}'"
    echo ""
    hm_vars="/etc/profiles/per-user/${USER}/etc/profile.d/hm-session-vars.sh"
    [[ -f "$hm_vars" ]] && bash -lc "source '$hm_vars'" || true
    print_header "END"

[doc('nh switch only; skip flake check and pre-commit git step')]
[group('switch')]
switch-fast:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
    print_header "SWITCH"
    notify "Flake Switch" "Fast" "info"; echo ""
    h="$(get_host "")"
    is_darwin && sc="nh darwin switch '${FLAKE}#${h}'" || sc="nh os switch '${FLAKE}#${h}'"
    notify "Flake Switch" "Switching $h..." "pending"
    print_info "-> $sc"; run_logged "Flake Switch" bash -lc "$sc"; print_header "END"

[doc('nix flake check only (no switch)')]
[group('switch')]
switch-check:
    #!/usr/bin/env bash
    set -euo pipefail
    source "$FLAKE/scripts/shell/common.sh"
    raise_fd_limit
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
    print_pending "treefmt   formatting .nix files..."
    treefmt -q "$FLAKE" || { print_error "treefmt   failed"; exit 1; }
    print_success "treefmt   done"
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
    # No cross-tree import climbs in modules/ — use `dotfilesLib` (specialArg)
    # or `config.lib.dotfiles` (HM) instead; see modules/AGENTS.md.
    if rg -n 'import \.\./\.\./\.\.' "$FLAKE/modules" --glob '*.nix'; then
        print_error "deep relative import (3+ levels) in modules/ — use dotfilesLib / config.lib.dotfiles"
        exit 1
    fi
    deadnix "$FLAKE"
    statix check "$FLAKE"
    print_header "END"

[doc('Quiet treefmt (e.g. for git hook)')]
[group('format')]
fmt-notree:
    @treefmt -q "$FLAKE" >/dev/null


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

[doc('Create sops editor age key under ~/.config/sops/age (Linux/macOS)')]
[group('config')]
setup-age-editor:
    #!/usr/bin/env bash
    set -euo pipefail
    kd="${HOME}/.config/sops/age"
    kf="$kd/keys.txt"
    mkdir -p "$kd"
    if [[ ! -f "$kf" ]]; then
      nix develop "$FLAKE" --command age-keygen -o "$kf"
    fi
    chmod 600 "$kf"
    echo "Editor public key (add as &editor in .sops.yaml if rotating):"
    nix develop "$FLAKE" --command age-keygen -y "$kf"

[doc('Create caya HM/runtime age key (~/.config/sops/age/keys.txt); must match &caya')]
[group('config')]
setup-age-darwin:
    @just setup-age-editor

[doc('First install only: create NixOS host age key at /var/lib/private/sops/age/keys.txt')]
[group('config')]
bootstrap-sops-host-key:
    #!/usr/bin/env bash
    set -euo pipefail
    host_dir="/var/lib/private/sops/age"
    host_key="$host_dir/keys.txt"
    # Host key is root:root 600 — plain [[ -f ]] fails for non-root.
    if sudo test -f "$host_key"; then
      echo "Host key already exists at $host_key" >&2
      echo "  First install on a fresh box: you already have a key — skip bootstrap." >&2
      echo "  Phase 1 temporary copy from editor: use rotate-sops-host-key for a dedicated key." >&2
      echo "  Current public key:" >&2
      sudo nix develop "$FLAKE" --command age-keygen -y "$host_key"
      exit 1
    fi
    sudo mkdir -p "$host_dir"
    sudo nix develop "$FLAKE" --command age-keygen -o "$host_key"
    sudo chmod 700 "$host_dir"
    sudo chmod 600 "$host_key"
    echo ""
    echo "Host public key — add/replace the matching &<hostKey> entry in .sops.yaml:"
    sudo nix develop "$FLAKE" --command age-keygen -y "$host_key"
    echo ""
    echo "Next: sops updatekeys secrets/secrets.yaml && git add .sops.yaml secrets/secrets.yaml && flake switch"

[doc('Quick unblock: install editor key as host key (temporary; rotate before production)')]
[group('config')]
bootstrap-sops-host-key-from-editor:
    #!/usr/bin/env bash
    set -euo pipefail
    editor_key="${HOME}/.config/sops/age/keys.txt"
    host_dir="/var/lib/private/sops/age"
    host_key="$host_dir/keys.txt"
    [[ -f "$editor_key" ]] || { echo "Missing $editor_key — run: just setup-age-editor" >&2; exit 1; }
    if sudo test -f "$host_key"; then
      echo "Host key already exists at $host_key" >&2
      echo "Use: just verify-sops-host-key" >&2
      echo "To replace with a dedicated key: just rotate-sops-host-key" >&2
      exit 1
    fi
    sudo mkdir -p "$host_dir"
    sudo install -m 600 -o root -g root "$editor_key" "$host_key"
    sudo chmod 700 "$host_dir"
    echo "Installed editor key as temporary host runtime key at $host_key"
    echo "Works only while &<hostKey> matches &editor in .sops.yaml."
    echo "Before treating this host as done: just rotate-sops-host-key (see docs/secrets/sops-age-keys.md Phase 2)."

[doc('Replace host age key: backup old, generate new, print pubkey — update .sops.yaml + updatekeys BEFORE switch')]
[group('config')]
rotate-sops-host-key:
    #!/usr/bin/env bash
    set -euo pipefail
    host_dir="/var/lib/private/sops/age"
    host_key="$host_dir/keys.txt"
    if ! sudo test -f "$host_key"; then
      echo "No host key at $host_key — run: just bootstrap-sops-host-key-from-editor or just bootstrap-sops-host-key" >&2
      exit 1
    fi
    ts="$(date -u +%Y%m%d-%H%M%S)"
    backup="$host_key.bak.$ts"
    sudo cp -a "$host_key" "$backup"
    sudo chmod 600 "$backup"
    echo "Backed up previous host key to $backup"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    rm -f "$tmp"
    nix develop "$FLAKE" --command age-keygen -o "$tmp"
    sudo install -m 600 -o root -g root "$tmp" "$host_key"
    sudo chmod 700 "$host_dir"
    echo ""
    echo "NEW host public key — update &<hostKey> in .sops.yaml to this value:"
    sudo nix develop "$FLAKE" --command age-keygen -y "$host_key"
    echo ""
    echo "STOP — required before flake switch on this host:"
    echo "  1. Edit .sops.yaml (&<hostKey> = pubkey above; must differ from &editor)"
    echo "  2. sops updatekeys secrets/secrets.yaml"
    echo "  3. git commit .sops.yaml secrets/secrets.yaml && git pull on this host"
    echo "  4. just verify-sops-host-key <hostKey>"
    echo "  5. flake switch"
    echo ""
    echo "Store backup offline: $backup"

[doc('Verify host runtime pubkey vs .sops.yaml anchor; fails if host still equals editor')]
[group('config')]
verify-sops-host-key anchor="framework":
    #!/usr/bin/env bash
    set -euo pipefail
    host_key="/var/lib/private/sops/age/keys.txt"
    editor_key="${HOME}/.config/sops/age/keys.txt"
    sops_yaml="$FLAKE/.sops.yaml"
    anchor="{{anchor}}"
    sudo test -f "$host_key" || { echo "Missing $host_key" >&2; exit 1; }
    host_pub="$(sudo nix develop "$FLAKE" --command age-keygen -y "$host_key")"
    editor_pub=""
    if [[ -f "$editor_key" ]]; then
      editor_pub="$(nix develop "$FLAKE" --command age-keygen -y "$editor_key")"
    fi
    anchor_pub="$(grep -E "^[[:space:]]*-[[:space:]]*&${anchor}[[:space:]]+age1" "$sops_yaml" | awk '{print $NF}' | head -1 || true)"
    editor_yaml_pub="$(grep -E "^[[:space:]]*-[[:space:]]*&editor[[:space:]]+age1" "$sops_yaml" | awk '{print $NF}' | head -1 || true)"
    echo "host runtime ($host_key): $host_pub"
    echo "editor (~/.config/sops/age/keys.txt): ${editor_pub:-<missing>}"
    echo ".sops.yaml &${anchor}: ${anchor_pub:-<not found>}"
    echo ".sops.yaml &editor: ${editor_yaml_pub:-<not found>}"
    failed=0
    if [[ -n "$editor_pub" && "$host_pub" == "$editor_pub" ]]; then
      echo "FAIL: host key still equals editor private key — run: just rotate-sops-host-key" >&2
      failed=1
    fi
    if [[ -n "$anchor_pub" && "$host_pub" != "$anchor_pub" ]]; then
      echo "FAIL: host pubkey != .sops.yaml &${anchor} — update yaml + sops updatekeys before switch" >&2
      failed=1
    fi
    if [[ -n "$editor_yaml_pub" && -n "$anchor_pub" && "$anchor_pub" == "$editor_yaml_pub" ]]; then
      echo "FAIL: &${anchor} still equals &editor in .sops.yaml — rotate host key and update yaml" >&2
      failed=1
    fi
    if [[ $failed -eq 0 ]]; then
      echo "OK: host key matches &${anchor} and is dedicated (not editor)"
    fi
    exit "$failed"


[doc('Post-switch: Context7 CLI skills (Claude, Cursor, OpenCode); needs ctx7 login or CONTEXT7_API_KEY')]
[group('config')]
post-install:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "$FLAKE/scripts/shell/post-install.bash"

[doc('Sync sops secrets into 1Password "Employee" vault (Darwin); needs op signin')]
[group('config')]
sync-1password:
    #!/usr/bin/env bash
    set -euo pipefail
    bash "$FLAKE/scripts/shell/sync-1password.bash"


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
    raise_fd_limit
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
    treefmt -q "$FLAKE" >/dev/null 2>&1 || true
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
      if command -v tv >/dev/null 2>&1; then
        attr="$(printf '%s\n' "${pkg_attrs[@]}" | tv --no-preview --no-remote --no-sort --input-prompt 'nix-update> ' --height 20 2>/dev/null || true)"
      elif command -v fzf >/dev/null 2>&1; then
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


[doc('Write spaces.nix + pins.nix from live Zen; then nix fmt (see scripts/README.md)')]
[group('zen')]
zen-sync *ARGS:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" zen-sync {{ ARGS }} && nix fmt .

[doc('Check flake spaces/pins vs live Zen session (exit 0 = match)')]
[group('zen')]
zen-check *ARGS:
    @cd "$FLAKE" && uv run --project "$FLAKE/scripts" zen-sync --check {{ ARGS }}



# Mini host + LLM commands, grouped as a module: `just mini <cmd>` and
# `just mini llm <cmd>`. Definitions live in just/mini.just + just/mini-llm.just.
mod mini "just/mini.just"

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
