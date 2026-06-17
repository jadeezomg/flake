#!/usr/bin/env bash
set -euo pipefail

root="${1:-${FLAKE:-$(pwd)}}"
export FLAKE="$root"
export JUSTFILE="${JUSTFILE:-$root/Justfile}"

source "$root/scripts/shell/common.sh"

active_host="${JUST_ACTIVE_HOST:-}"
config_file="$root/.flake-host"
if [[ -z "$active_host" && -f "$config_file" ]]; then
  IFS= read -r active_host <"$config_file" || true
  active_host="${active_host//[[:space:]]/}"
fi
if [[ -z "$active_host" ]]; then
  active_host="$(detect_host_from_hostname || true)"
fi

known_hosts=()
for host_dir in "$root"/hosts/*; do
  [[ -d "$host_dir" ]] || continue
  known_hosts+=("${host_dir##*/}")
done

for recipe in $(just --justfile "$JUSTFILE" --summary 2>/dev/null); do
  host_scoped=0
  for host in "${known_hosts[@]}"; do
    if [[ "$recipe" == "$host"-* ]]; then
      host_scoped=1
      if [[ "$host" == "$active_host" ]]; then
        printf '%s\n' "$recipe"
      fi
      break
    fi
  done
  if [[ "$host_scoped" == 0 ]]; then
    printf '%s\n' "$recipe"
  fi
done
