#!/usr/bin/env bash
# Diff agent-skills/ against the locked skills-mattpocock input.
# Usage: just skills-upstream [--bump] [--apply-all]
#   --bump       run `nix flake update skills-mattpocock` first
#   --apply-all  copy upstream over local for every changed skill (no prompt)
set -euo pipefail

source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

INPUT_NAME="skills-mattpocock"
LOCAL_DIR="${FLAKE}/agent-skills"
IGNORE_FILE="${LOCAL_DIR}/.upstream-ignore"
BUMP=0
APPLY_ALL=0

for arg in "$@"; do
  case "$arg" in
    --bump) BUMP=1 ;;
    --apply-all) APPLY_ALL=1 ;;
    -h|--help)
      sed -n '2,5p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) print_error "unknown arg: $arg"; exit 2 ;;
  esac
done

print_header "SKILLS UPSTREAM"

if [[ $BUMP -eq 1 ]]; then
  print_pending "bumping ${INPUT_NAME} input"
  nix flake update "${INPUT_NAME}" --flake "${FLAKE}"
  print_success "input updated"
fi

print_pending "resolving upstream store path"
upstream="$(nix eval --raw --impure --expr "(builtins.getFlake \"${FLAKE}\").inputs.${INPUT_NAME}.outPath")"
print_info "upstream: ${upstream}"

# Skills the user has explicitly opted out of (one name per line, # comments)
declare -A IGNORED=()
if [[ -f "${IGNORE_FILE}" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] || IGNORED["$line"]=1
  done < "${IGNORE_FILE}"
fi

# Collect skill names that exist in BOTH local and upstream and have SKILL.md
mapfile -t common < <(
  for d in "${LOCAL_DIR}"/*/; do
    n="$(basename "$d")"
    if [[ -f "${LOCAL_DIR}/${n}/SKILL.md" && -f "${upstream}/${n}/SKILL.md" ]]; then
      printf '%s\n' "$n"
    fi
  done | sort -u
)

if [[ ${#common[@]} -eq 0 ]]; then
  print_info "no overlapping skills"
  print_header "END"
  exit 0
fi

# Find which differ
changed=()
for n in "${common[@]}"; do
  if ! diff -rq "${LOCAL_DIR}/${n}" "${upstream}/${n}" >/dev/null 2>&1; then
    changed+=("$n")
  fi
done

# Also report upstream-only skills (potential adds), respecting .upstream-ignore
mapfile -t upstream_only < <(
  for d in "${upstream}"/*/; do
    n="$(basename "$d")"
    [[ -f "${upstream}/${n}/SKILL.md" ]] || continue
    [[ -e "${LOCAL_DIR}/${n}" ]] && continue
    [[ -n "${IGNORED[$n]:-}" ]] && continue
    printf '%s\n' "$n"
  done | sort -u
)

echo
if [[ ${#changed[@]} -eq 0 ]]; then
  print_success "all ${#common[@]} overlapping skill(s) match upstream"
else
  print_pending "${#changed[@]} of ${#common[@]} skill(s) differ from upstream:"
  for n in "${changed[@]}"; do printf '  %b~%b %s\n' "${THEME_YELLOW}" "${THEME_RESET}" "${n}"; done
fi

if [[ ${#upstream_only[@]} -gt 0 ]]; then
  echo
  print_info "upstream-only (not in flake): ${#upstream_only[@]}"
  for n in "${upstream_only[@]}"; do printf '  %b+%b %s\n' "${THEME_CYAN}" "${THEME_RESET}" "${n}"; done
fi

if [[ ${#changed[@]} -eq 0 ]]; then
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
  local n="$1"
  rm -rf "${LOCAL_DIR:?}/${n}"
  cp -r --no-preserve=mode "${upstream}/${n}" "${LOCAL_DIR}/${n}"
  chmod -R u+w "${LOCAL_DIR}/${n}"
  print_success "applied: ${n}"
}

if [[ $APPLY_ALL -eq 1 ]]; then
  echo
  for n in "${changed[@]}"; do apply "$n"; done
  print_header "END"
  exit 0
fi

echo
print_info "interactive review — [v]iew diff / [a]pply / [s]kip / [q]uit"
for n in "${changed[@]}"; do
  while true; do
    read -r -p "${n} > [v/a/s/q]: " ans || ans=q
    case "${ans,,}" in
      v|view)
        diff_tool "${LOCAL_DIR}/${n}" "${upstream}/${n}" | ${PAGER:-less -R}
        ;;
      a|apply)
        apply "$n"
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
