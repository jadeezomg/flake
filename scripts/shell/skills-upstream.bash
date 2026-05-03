#!/usr/bin/env bash
# Diff agent-skills/ against ~/Git/skills (nested category structure).
# Usage: just skills-upstream [--apply-all]
#   --apply-all  copy upstream over local for every changed skill (no prompt)
set -euo pipefail

source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

LOCAL_DIR="${FLAKE}/agent-skills"
UPSTREAM_DIR="${HOME}/Git/skills/skills"
IGNORE_FILE="${LOCAL_DIR}/.upstream-ignore"
APPLY_ALL=0

for arg in "$@"; do
  case "$arg" in
    --apply-all) APPLY_ALL=1 ;;
    -h|--help)
      sed -n '2,4p' "$0" | sed 's/^# \?//'
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
for cat_dir in "${UPSTREAM_DIR}"/*/; do
  cat="$(basename "$cat_dir")"
  [[ "$cat" == "deprecated" ]] && continue
  for skill_dir in "${cat_dir}"*/; do
    [[ -d "$skill_dir" ]] || continue
    n="$(basename "$skill_dir")"
    upstream_map["$n"]="${skill_dir%/}"
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
changed_local=()
changed_upstream=()
for n in "${!local_map[@]}"; do
  [[ -v upstream_map["$n"] ]] || continue
  if ! diff -rq "${local_map[$n]}" "${upstream_map[$n]}" >/dev/null 2>&1; then
    changed_names+=("$n")
    changed_local+=("${local_map[$n]}")
    changed_upstream+=("${upstream_map[$n]}")
  fi
done
# Sort for stable output
IFS=$'\n' changed_names=($(sort <<<"${changed_names[*]+"${changed_names[*]}"}")); unset IFS

# Find upstream-only (potential adds), respecting .upstream-ignore
upstream_only=()
for n in "${!upstream_map[@]}"; do
  [[ -v local_map["$n"] ]] && continue
  [[ -n "${IGNORED[$n]:-}" ]] && continue
  upstream_only+=("$n")
done
IFS=$'\n' upstream_only=($(sort <<<"${upstream_only[*]+"${upstream_only[*]}"}")); unset IFS

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
    # find its category
    cat="unknown"
    for cat_dir in "${UPSTREAM_DIR}"/*/; do
      [[ -d "${cat_dir}${n}" ]] && cat="$(basename "$cat_dir")" && break
    done
    printf '  %b+%b %s (%s)\n' "${THEME_CYAN}" "${THEME_RESET}" "${n}" "${cat}"
  done
fi

if [[ ${#changed_names[@]} -eq 0 ]]; then
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
  rm -rf "${local_path:?}"
  cp -r --no-preserve=mode "${upstream_path}" "${local_path}"
  chmod -R u+w "${local_path}"
  print_success "applied: ${n}"
}

if [[ $APPLY_ALL -eq 1 ]]; then
  echo
  for i in "${!changed_names[@]}"; do
    apply "${changed_names[$i]}" "${changed_local[$i]}" "${changed_upstream[$i]}"
  done
  print_header "END"
  exit 0
fi

echo
print_info "interactive review — [v]iew diff / [a]pply / [s]kip / [q]uit"
for i in "${!changed_names[@]}"; do
  n="${changed_names[$i]}"
  while true; do
    read -r -p "${n} > [v/a/s/q]: " ans || ans=q
    case "${ans,,}" in
      v|view)
        diff_tool "${changed_local[$i]}" "${changed_upstream[$i]}" | ${PAGER:-less -R}
        ;;
      a|apply)
        apply "$n" "${changed_local[$i]}" "${changed_upstream[$i]}"
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

print_header "END"
