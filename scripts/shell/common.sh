#!/usr/bin/env bash
set -euo pipefail

# Theme: from env when invoked via `just` (Justfile exports), else inline fallback.
if [[ -z "${THEME_RESET:-}" ]]; then
  export THEME_GREEN='\033[32m'        THEME_GREEN_BOLD='\033[1;32m'
  export THEME_YELLOW='\033[33m'       THEME_YELLOW_BOLD='\033[1;33m'
  export THEME_RED='\033[31m'          THEME_RED_BOLD='\033[1;31m'
  export THEME_CYAN='\033[36m'         THEME_CYAN_BOLD='\033[1;36m'
  export THEME_RESET='\033[0m'
  export ICON_SUCCESS="${THEME_GREEN}▲${THEME_RESET}"
  export ICON_PENDING="${THEME_YELLOW}❖${THEME_RESET}"
  export ICON_ERROR="${THEME_RED}▼${THEME_RESET}"
  export ICON_INFO="${THEME_CYAN}▪${THEME_RESET}"
fi

flake_root() {
  if [[ -n "${FLAKE:-}" ]]; then
    echo "$FLAKE"
  else
    echo "${HOME}/.dotfiles/flake"
  fi
}

get_hostname_lc() {
  if command -v hostname >/dev/null 2>&1; then
    hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || hostname | tr '[:upper:]' '[:lower:]'
  elif [[ -n "${HOSTNAME:-}" ]]; then
    echo "${HOSTNAME,,}"
  else
    echo "unknown"
  fi
}

is_darwin() {
  local h
  h="$(get_hostname_lc)"
  [[ "$h" == *darwin* ]] || [[ "$h" == *caya* ]] || [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]
}

nh_prefix() {
  if is_darwin; then
    echo "nh darwin"
  else
    echo "nh os"
  fi
}

build_nh_cmd() {
  local action="${1:-switch}"
  local prefix
  prefix="$(nh_prefix)"
  case "$action" in
    switch) echo "${prefix} switch" ;;
    build) echo "${prefix} build" ;;
    boot)
      if is_darwin; then echo "${prefix} build"; else echo "${prefix} boot"; fi
      ;;
    dry)
      if is_darwin; then echo "${prefix} build --dry-run"; else echo "${prefix} test"; fi
      ;;
    dev) echo "${prefix} switch --show-trace" ;;
    *) echo "${prefix} ${action}" ;;
  esac
}

notify() {
  local title="$1" msg="$2"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="flake-build" "$title" "$msg"
  else
    echo -e "${ICON_INFO} ${title}: ${msg}"
  fi
}

print_header() {
  local title="$1"
  echo -e "${THEME_CYAN_BOLD}━━ ${title} ━━${THEME_RESET}"
}

print_success() { echo -e "${ICON_SUCCESS} $*"; }
print_pending() { echo -e "${ICON_PENDING} $*"; }
print_error() { echo -e "${ICON_ERROR} $*"; }
print_info() { echo -e "${ICON_INFO} $*"; }

detect_host_from_hostname() {
  local h
  h="$(get_hostname_lc)"
  if [[ "$h" == *framework* ]]; then echo framework
  elif [[ "$h" == *desktop* ]]; then echo desktop
  elif [[ "$h" == *caya* ]]; then echo caya
  else echo ""; fi
}

get_host() {
  local provided="${1:-}"
  local root config_file detected
  root="$(flake_root)"
  config_file="${root}/.flake-host"
  if [[ -n "$provided" ]]; then
    echo "$provided"
    return
  fi
  if [[ -f "$config_file" ]]; then
    local saved
    saved="$(tr -d '[:space:]' <"$config_file" || true)"
    if [[ -n "$saved" ]]; then
      echo "$saved"
      return
    fi
  fi
  detected="$(detect_host_from_hostname)"
  if [[ -n "$detected" ]]; then
    echo "$detected"
    return
  fi
  read -r -p "Host not detected. Enter host (e.g. framework/desktop/caya): " prompted || true
  prompted="${prompted//[[:space:]]/}"
  if [[ -z "$prompted" ]]; then
    print_error "Host is required; run 'flake init <host>'."
    exit 1
  fi
  echo "$prompted"
}

set_host() {
  local host="$1"
  local root config_file
  root="$(flake_root)"
  config_file="${root}/.flake-host"
  printf '%s\n' "$host" >"$config_file"
  print_success "Default host set to: $host"
  print_info "Config saved to: $config_file"
}

confirm() {
  local r
  read -r -p "$1 (y/N): " r || true
  [[ "${r,,}" == "y" || "${r,,}" == "yes" ]]
}

prompt_number() {
  local msg="$1" default="" input
  if [[ "$msg" =~ default:[[:space:]]*([0-9]+) ]]; then
    default="${BASH_REMATCH[1]}"
  fi
  read -r -p "${msg} ${default:+[default: $default] }: " input || true
  input="${input//[[:space:]]/}"
  if [[ -z "$input" && -n "$default" ]]; then echo "$default"; return; fi
  if [[ -z "$input" ]]; then echo ""; return 1; fi
  if [[ "${input,,}" == "abort" ]]; then echo ""; return 1; fi
  if [[ "$input" =~ ^[0-9]+$ ]]; then echo "$input"; return; fi
  print_error "Invalid number: $input"
  return 1
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
