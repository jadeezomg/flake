#!/usr/bin/env bash
# Invoked as: bash flake-recipes.bash <cmd> [args...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"
CMD="${1:?}"; shift || true

do_build() {
  MODES=(build boot dry dev)
  is_mode() { local m="${1#--}"; for x in "${MODES[@]}"; do [[ "$x" == "$m" ]] && return 0; done; return 1; }
  print_header "BUILD"
  selected_mode="build" host_arg="" sc=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --build|--boot|--dry|--dev) selected_mode="${1#--}"; shift ;;
      -*) print_error "Unknown: $1"; exit 1 ;;
      *) host_arg="$1"; shift ;;
    esac
  done
  target_host="$(get_host "$host_arg")"
  is_mode "$selected_mode" || exit 1
  if is_darwin; then
    case "$selected_mode" in
      build) sc="nh darwin build --flake '${FLAKE}#${target_host}'" ;;
      boot) sc="nh darwin build --flake '${FLAKE}#${target_host}'" ;;
      dry) sc="nh darwin build --dry-run --flake '${FLAKE}#${target_host}'" ;;
      dev) sc="nh darwin switch --show-trace --flake '${FLAKE}#${target_host}'" ;;
    esac
  else
    case "$selected_mode" in
      build) sc="nh os build --flake '${FLAKE}#${target_host}'" ;;
      boot) sc="nh os boot --flake '${FLAKE}#${target_host}'" ;;
      dry) sc="nh os test --flake '${FLAKE}#${target_host}'" ;;
      dev) sc="nh os switch --show-trace --flake '${FLAKE}#${target_host}'" ;;
    esac
  fi
  case "$selected_mode" in
    build) notify "Flake Build" "Building $target_host..." "pending"; print_info "→ $sc"; bash -c "$sc"; notify "Flake Build" "OK" "success" ;;
    boot) notify "Flake Build" "Boot $target_host..." "pending"; print_info "→ $sc"; bash -c "$sc"; notify "Flake Build" "Next reboot" "success" ;;
    dry) notify "Flake Build" "Dry $target_host..." "pending"; print_info "→ $sc"; bash -c "$sc" ;;
    dev) notify "Flake Build" "Trace $target_host..." "pending"; print_info "→ $sc"; bash -c "$sc" ;;
  esac
  print_header "END"
}

do_switch() {
  print_header "SWITCH"
  FLAKE_PATH="$(flake_root)" fast=0 check_only=0 skip_git=0 override_input="" host_arg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fast) fast=1; shift ;;
      --check) check_only=1; shift ;;
      --skip-git) skip_git=1; shift ;;
      --override-input) override_input="${2:-}"; shift 2 ;;
      *)
        if [[ "$1" != -* && -z "$host_arg" ]]; then host_arg="$1"; fi
        shift
        ;;
    esac
  done
  target_host="$(get_host "$host_arg")"
  if [[ "$fast" -eq 0 && "$skip_git" -eq 0 ]]; then
    JUSTFILE="${JUSTFILE:-$FLAKE_PATH/Justfile}"
    command -v just >/dev/null && just --justfile "$JUSTFILE" git || true
    echo ""
  fi
  [[ "$fast" -eq 1 ]] && notify "Flake Switch" "Fast" "info" && echo ""
  if [[ "$fast" -eq 0 ]]; then
    notify "Flake Switch" "Pre-flight..." "pending"
    bash -lc "nix flake check --all-systems $FLAKE_PATH --no-write-lock-file" && notify "Flake Switch" "OK" "success" || notify "Flake Switch" "Check failed [continue]" "pending"
    echo ""
  fi
  [[ "$check_only" -eq 1 ]] && print_header "END" && exit 0
  notify "Flake Switch" "Switching $target_host..." "pending"
  if [[ -n "$override_input" ]]; then
    IFS='=' read -r in_n in_v <<<"$override_input"
    if is_darwin; then sc="nh darwin switch --flake '${FLAKE_PATH}#${target_host}' --override-input $in_n $in_v"
    else sc="nh os switch --flake '${FLAKE_PATH}#${target_host}' --override-input $in_n $in_v"; fi
  else
    if is_darwin; then sc="nh darwin switch --flake '${FLAKE_PATH}#${target_host}'"
    else sc="nh os switch --flake '${FLAKE_PATH}#${target_host}'"; fi
  fi
  print_info "→ $sc"; bash -lc "$sc"; echo ""
  if [[ "$fast" -eq 0 ]]; then
    hm_vars="/etc/profiles/per-user/${USER}/etc/profile.d/hm-session-vars.sh"
    [[ -f "$hm_vars" ]] && bash -lc "source '$hm_vars'" || true
  fi
  print_header "END"
}

do_generation() {
  action="${1:-list}" num="${2:-}"
  list_gen() {
    if is_darwin; then print_header "DARWIN"; darwin-rebuild --list-generations 2>/dev/null || print_error "list failed"
    else print_header "NIXOS"; nh os info; fi
  }
  case "$action" in
    list) list_gen ;;
    bootloader)
      if is_darwin; then print_error "N/A on Darwin"; exit 0; fi
      print_header "BOOTLOADER"; bootctl list 2>/dev/null || true
      for e in /boot/efi/EFI/Linux /boot/EFI/Linux; do [[ -d "$e" ]] && ls -la "$e"; done
      command_exists efibootmgr && efibootmgr -v || true ;;
    switch)
      num="${3:-$num}"; [[ -z "$num" && $# -ge 2 ]] && num="$2"
      list_gen; echo ""
      [[ -z "$num" ]] && num="$(prompt_number "Generation #")" || true
      [[ -z "$num" ]] && exit 0
      if is_darwin; then darwin-rebuild switch --rollback-to "$num"; else nh os rollback --to "$num"; fi ;;
    delete)
      num="${3:-$num}"; [[ -z "$num" && $# -ge 2 ]] && num="$2"
      list_gen; echo ""
      [[ -z "$num" ]] && num="$(prompt_number "Delete #")" || true
      [[ -z "$num" ]] && exit 0
      sudo nix-env --delete-generations "$num" -p /nix/var/nix/profiles/system ;;
    *) print_error "list|bootloader|switch N|delete N"; exit 1 ;;
  esac
  print_header "END"
}

do_gc() {
  print_header "GC"
  [[ $# -eq 0 ]] && exit 1
  case "$1" in
    --keep|keep)
      n="${2:-}"; [[ -z "$n" ]] && n="$(prompt_number "Keep N [5]")" || true; nh clean all --keep "${n:-5}" ;;
    --days|days)
      d="${2:-}"; [[ -z "$d" ]] && d="$(prompt_number "Days [7]")" || true; nh clean all --keep-since "${d:-7}d" ;;
    --all|all)
      nh clean all
      tr="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
      if [[ -d "$tr" ]]; then rm -rf "$tr" 2>/dev/null || sudo rm -rf "$tr" 2>/dev/null || true; fi ;;
    *) exit 1 ;;
  esac
  print_header "END"
}

do_fmt() {
  no_tree=0 quiet=0
  for a in "$@"; do [[ "$a" == "--no-tree" ]] && no_tree=1; [[ "$a" == "--quiet" ]] && quiet=1; done
  [[ "$quiet" -eq 0 ]] && print_header "FMT"
  command_exists alejandra || exit 1
  F="$(flake_root)" changed=0 unchanged=0 failed=0
  while IFS= read -r -d '' f; do
    [[ "$(basename "$f")" == default.nix ]] && continue
    mb=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
    if alejandra "$f" >/dev/null 2>&1; then
      ma=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
      if [[ "$ma" != "$mb" ]]; then changed=$((changed + 1)); else unchanged=$((unchanged + 1)); fi
    else failed=$((failed + 1)); fi
  done < <(find "$F" -name "*.nix" -type f -print0 2>/dev/null)
  [[ "$failed" -gt 0 ]] && exit 1
  [[ "$no_tree" -eq 0 && "$quiet" -eq 0 ]] && echo "changed:$changed unchanged:$unchanged"
  [[ "$quiet" -eq 0 ]] && print_header "END"
}

do_backups() {
  clean=0 dry=0; for a in "$@"; do [[ "$a" == "--clean" ]] && clean=1; [[ "$a" == "--dry" ]] && dry=1; done
  print_header "BACKUPS"
  mapfile -t files < <(find "${HOME}/.config" \( -name "*.backup" -o -name "*.bkp" \) -type f 2>/dev/null)
  [[ ${#files[@]} -eq 0 ]] && print_header "END" && exit 0
  for f in "${files[@]}"; do du -h "$f" 2>/dev/null | awk -v p="$f" '{print $1,p}'; done
  if [[ "$clean" -eq 1 ]]; then for f in "${files[@]}"; do [[ "$dry" -eq 1 ]] && echo "would: $f" || rm -f "$f"; done; fi
  print_header "END"
}

do_rollback() {
  print_header "ROLLBACK"
  if is_darwin; then darwin-rebuild switch --rollback; else nh os rollback; fi
  print_header "END"
}

do_health() {
  print_header "HEALTH"
  F="$(flake_root)"
  git -C "$F" status --short 2>/dev/null | head -5
  df -h / 2>/dev/null | head -2
  is_darwin || nh os info 2>/dev/null | head -15
  print_header "END"
}

do_init() {
  print_header "INIT"
  local t="${1:-}" cf msg prev
  if [[ -z "${t// }" ]]; then
    t="$(detect_host_from_hostname)" || t=""
    read -r -p "Host [${t:-detect}]: " msg || true
    [[ -n "${msg// }" ]] && t="$msg"
    [[ -z "${t// }" ]] && {
      print_error "Unknown host; run: flake init <hostname>"
      exit 1
    }
  fi
  cf="${FLAKE}/.flake-host"
  if [[ -f "$cf" ]]; then
    prev=$(tr -d '[:space:]' <"$cf" || true)
    if [[ -n "$prev" && "$prev" != "$t" ]] && ! confirm "Overwrite $prev → $t?"; then print_info "Unchanged."; exit 0; fi
  fi
  set_host "$t"
  print_header "END"
}

do_git() {
  F="$(flake_root)"; [[ -d "$F/.git" ]] || exit 1
  do_fmt --no-tree --quiet 2>/dev/null || true
  git -C "$F" status -sb; git -C "$F" log --oneline -n 5
  read -r -p "Commit: " msg || true
  [[ -z "${msg:-}" || "$msg" == abort ]] && exit 0
  git -C "$F" add -A && git -C "$F" commit -m "$msg" && git -C "$F" push
}

do_setup_age() {
  kd="${HOME}/.config/sops/age" kf="$kd/keys.txt"
  mkdir -p "$kd"
  [[ ! -f "$kf" ]] && nix develop "$(flake_root)" --command age-keygen -o "$kf"
  nix develop "$(flake_root)" --command age-keygen -y "$kf"
}

do_zen_check() {
  Z="${HOME}/.zen/default" D="$Z/places.sqlite"
  [[ -d "$Z" && -f "$D" ]] || exit 1
  echo "OK $D"
}

case "$CMD" in
  build) do_build "$@" ;;
  switch) do_switch "$@" ;;
  generation) do_generation "$@" ;;
  gc) do_gc "$@" ;;
  fmt) do_fmt "$@" ;;
  backups) do_backups "$@" ;;
  init) do_init "$@" ;;
  rollback) do_rollback ;;
  health) do_health ;;
  git) do_git ;;
  setup-age-darwin) do_setup_age ;;
  check-zen) do_zen_check ;;
  *) echo "unknown: $CMD"; exit 1 ;;
esac
