#!/usr/bin/env bash
# Diff data/agents/skills/ against the pinned `skills-mattpocock` flake input
# (nested category structure). The pin updates via `just update`.
# Usage: just skills-upstream [--apply-all] [--import-new]
#   --apply-all  copy upstream over local for every changed skill (no prompt)
#   --import-new with --apply-all, import upstream-only skills too
set -euo pipefail

source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

LOCAL_DIR="${FLAKE}/data/agents/skills"
# Store path of the `skills-mattpocock` input, exposed by parts/lib.nix.
UPSTREAM_SRC="$(nix eval --raw "${FLAKE}#lib.skillsUpstreamSrc")"
UPSTREAM_DIR="${UPSTREAM_SRC}/skills"
IGNORE_FILE="${LOCAL_DIR}/.upstream-ignore"
APPLY_ALL=0
IMPORT_NEW=0

for arg in "$@"; do
  case "$arg" in
    --apply-all) APPLY_ALL=1 ;;
    --import-new) IMPORT_NEW=1 ;;
    -h|--help)
      sed -n '2,5p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) print_error "unknown arg: $arg"; exit 2 ;;
  esac
done

print_header "SKILLS UPSTREAM"
print_info "upstream: ${UPSTREAM_DIR}"

# Skills the user has explicitly opted out of (one name per line, # comments)
declare -A IGNORED=()
if [[ -f "${IGNORE_FILE}" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] || IGNORED["$line"]=1
  done < "${IGNORE_FILE}"
fi

# Build map: skillName -> upstream_path (skip deprecated)
declare -A upstream_map=()
declare -A upstream_cat=()
for cat_dir in "${UPSTREAM_DIR}"/*/; do
  cat="$(basename "$cat_dir")"
  [[ "$cat" == "deprecated" ]] && continue
  for skill_dir in "${cat_dir}"*/; do
    [[ -d "$skill_dir" ]] || continue
    n="$(basename "$skill_dir")"
    upstream_map["$n"]="${skill_dir%/}"
    upstream_cat["$n"]="$cat"
  done
done

# Build map: skillName -> local_path (skip deprecated and local categories)
declare -A local_map=()
for cat_dir in "${LOCAL_DIR}"/*/; do
  cat="$(basename "$cat_dir")"
  [[ "$cat" == "deprecated" || "$cat" == "local" ]] && continue
  for skill_dir in "${cat_dir}"*/; do
    [[ -d "$skill_dir" ]] || continue
    n="$(basename "$skill_dir")"
    local_map["$n"]="${skill_dir%/}"
  done
done

# Find changed (exist in both, differ)
changed_names=()
for n in "${!local_map[@]}"; do
  [[ -v upstream_map["$n"] ]] || continue
  if ! diff -rq "${local_map[$n]}" "${upstream_map[$n]}" >/dev/null 2>&1; then
    changed_names+=("$n")
  fi
done
# Sort for stable output
if [[ ${#changed_names[@]} -gt 0 ]]; then
  mapfile -t changed_names < <(printf '%s\n' "${changed_names[@]}" | sort)
fi

# Find upstream-only (potential adds), respecting .upstream-ignore
upstream_only=()
for n in "${!upstream_map[@]}"; do
  [[ -v local_map["$n"] ]] && continue
  [[ -n "${IGNORED[$n]:-}" ]] && continue
  upstream_only+=("$n")
done
if [[ ${#upstream_only[@]} -gt 0 ]]; then
  mapfile -t upstream_only < <(printf '%s\n' "${upstream_only[@]}" | sort)
fi

echo
if [[ ${#changed_names[@]} -eq 0 ]]; then
  print_success "all overlapping skills match upstream"
else
  print_pending "${#changed_names[@]} skill(s) differ from upstream:"
  for n in "${changed_names[@]}"; do printf '  %b~%b %s\n' "${THEME_YELLOW}" "${THEME_RESET}" "${n}"; done
fi

if [[ ${#upstream_only[@]} -gt 0 ]]; then
  echo
  print_info "upstream-only (not in flake): ${#upstream_only[@]}"
  for n in "${upstream_only[@]}"; do
    printf '  %b+%b %s (%s)\n' "${THEME_CYAN}" "${THEME_RESET}" "${n}" "${upstream_cat[$n]}"
  done
fi

if [[ ${#changed_names[@]} -eq 0 && ${#upstream_only[@]} -eq 0 ]]; then
  print_header "END"
  exit 0
fi

# Pick the diff renderer
diff_tool() {
  local a="$1" b="$2"
  if command_exists delta; then
    diff -ruN "$a" "$b" | delta --paging never || true
  elif command_exists bat; then
    diff -ruN --color=always "$a" "$b" | bat --paging=never -l diff || true
  else
    diff -ruN --color=always "$a" "$b" || true
  fi
}

apply() {
  local n="$1" local_path="$2" upstream_path="$3"
  trash_path "${local_path:?}"
  cp -r --no-preserve=mode "${upstream_path}" "${local_path}"
  chmod -R u+w "${local_path}"
  print_success "applied: ${n}"
}

trash_path() {
  local path="$1"
  if command_exists trash; then
    trash "$path"
  elif command_exists gio; then
    gio trash "$path"
  else
    print_error "no trash command found; refusing to remove ${path}"
    exit 1
  fi
}

import_new() {
  local n="$1" upstream_path="$2" dest_path
  dest_path="${LOCAL_DIR}/${upstream_cat[$n]}/${n}"
  if [[ -e "$dest_path" ]]; then
    print_error "refusing to import over existing path: ${dest_path}"
    return 1
  fi
  mkdir -p "${dest_path%/*}"
  cp -r --no-preserve=mode "${upstream_path}" "${dest_path}"
  chmod -R u+w "${dest_path}"
  print_success "imported: ${n} (${upstream_cat[$n]})"
}

ignore_new() {
  local n="$1" add_blank=0
  [[ -s "$IGNORE_FILE" ]] && add_blank=1
  mkdir -p "${IGNORE_FILE%/*}"
  [[ $add_blank -eq 1 ]] && printf '\n' >> "$IGNORE_FILE"
  printf '%s\n' "$n" >> "$IGNORE_FILE"
  print_success "ignored: ${n}"
}

if [[ $APPLY_ALL -eq 1 ]]; then
  echo
  for n in "${changed_names[@]}"; do
    apply "$n" "${local_map[$n]}" "${upstream_map[$n]}"
  done
  if [[ $IMPORT_NEW -eq 1 ]]; then
    for n in "${upstream_only[@]}"; do
      import_new "$n" "${upstream_map[$n]}"
    done
  fi
  print_header "END"
  exit 0
fi

echo
if [[ ${#changed_names[@]} -gt 0 ]]; then
  print_info "interactive review — [v]iew diff / [a]pply / [s]kip / [q]uit"
fi
for n in "${changed_names[@]}"; do
  while true; do
    read -r -p "${n} > [v/a/s/q]: " ans || ans=q
    case "${ans,,}" in
      v|view)
        diff_tool "${local_map[$n]}" "${upstream_map[$n]}" | ${PAGER:-less -R}
        ;;
      a|apply)
        apply "$n" "${local_map[$n]}" "${upstream_map[$n]}"
        break
        ;;
      s|skip|"")
        print_info "skipped: ${n}"
        break
        ;;
      q|quit)
        print_info "abort"
        print_header "END"
        exit 0
        ;;
      *) print_error "invalid: ${ans}" ;;
    esac
  done
done

if [[ ${#upstream_only[@]} -gt 0 ]]; then
  echo
  print_info "interactive import — [i]mport / i[g]nore / [s]kip / [q]uit"
  for n in "${upstream_only[@]}"; do
    while true; do
      read -r -p "${n} (${upstream_cat[$n]}) > [i/g/s/q]: " ans || ans=q
      case "${ans,,}" in
        i|import)
          import_new "$n" "${upstream_map[$n]}"
          break
          ;;
        g|ignore)
          ignore_new "$n"
          break
          ;;
        s|skip|"")
          print_info "skipped: ${n}"
          break
          ;;
        q|quit)
          print_info "abort"
          print_header "END"
          exit 0
          ;;
        *) print_error "invalid: ${ans}" ;;
      esac
    done
  done
fi

print_header "END"
