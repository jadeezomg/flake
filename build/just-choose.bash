#!/usr/bin/env bash
# Rich fzf chooser: show group + doc like `just --list` (stock --choose only gets names on stdin).
# https://just.systems/man/en/selecting-recipes-to-run-with-an-interactive-chooser.html
set -euo pipefail
J="${JUSTFILE:-}"
[[ -n "$J" && -f "$J" ]] || {
  echo "just-choose: JUSTFILE missing or not found" >&2
  exit 1
}
ROOT="$(cd "$(dirname "$J")" && pwd)"

if ! command -v fzf >/dev/null 2>&1; then
  exec just --justfile "$J" --choose
fi

# Parse `just --list --unsorted` → ordered names, group[], doc[]
declare -a order=()
declare -A grp doc
group=""
while IFS= read -r line; do
  [[ "$line" == "Available recipes:" ]] && continue
  [[ -z "${line// }" ]] && continue
  if [[ "$line" =~ ^[[:space:]]+\[([^]]+)\][[:space:]]*$ ]]; then
    group="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9][a-zA-Z0-9_-]*)[[:space:]]+#(.*)$ ]]; then
    r="${BASH_REMATCH[1]}"
    d="${BASH_REMATCH[2]}"
    d="${d#"${d%%[![:space:]]*}"}"
    d="${d%"${d##*[![:space:]]}"}"
    order+=("$r")
    grp["$r"]="${group:-ungrouped}"
    doc["$r"]="$d"
  elif [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9][a-zA-Z0-9_-]*)[[:space:]]*$ ]]; then
    r="${BASH_REMATCH[1]}"
    order+=("$r")
    grp["$r"]="${group:-ungrouped}"
    doc["$r"]=""
  fi
done < <(cd "$ROOT" && just --justfile "$J" --list --unsorted 2>/dev/null)

[[ ${#order[@]} -eq 0 ]] && exec just --justfile "$J" --choose

build_row() {
  local r="$1" g d
  g="${grp[$r]:-ungrouped}"
  d="${doc[$r]:-}"
  if [[ -n "$d" ]]; then
    printf '%s\t[%s]  %s  —  %s\n' "$r" "$g" "$r" "$d"
  else
    printf '%s\t[%s]  %s\n' "$r" "$g" "$r"
  fi
}

declare -a rows=()
if [[ -t 0 ]]; then
  # e.g. `just` / `just default` — show full list with groups + docs
  for r in "${order[@]}"; do
    rows+=("$(build_row "$r")")
  done
else
  # e.g. JUST_CHOOSER — stdin is recipe names from just; enrich each
  while IFS= read -r name; do
    [[ -z "${name// }" ]] && continue
    [[ -n "${grp[$name]+x}" ]] && rows+=("$(build_row "$name")")
  done
fi

[[ ${#rows[@]} -eq 0 ]] && exit 0

mapfile -t picked < <(
  printf '%s\n' "${rows[@]}" | fzf \
    --multi \
    --delimiter=$'\t' \
    --with-nth=2.. \
    --prompt='recipe › ' \
    --header='Tab=toggle · Enter=run · matches just --list (group + doc)' \
    --height=60% \
    --layout=reverse \
    2>/dev/null || true
)

[[ ${#picked[@]} -eq 0 ]] && exit 0
exec_args=()
for line in "${picked[@]}"; do
  exec_args+=("${line%%$'\t'*}")
done
exec just --justfile "$J" "${exec_args[@]}"
