#!/usr/bin/env bash
# Run after `just switch` on a new machine (or when wiring AI tooling).
# Extend this script with other one-time / rare post-switch steps as needed.
#
# Context7: the flake installs `ctx7` via Nix (home.shared.development.tooling.llm),
# not `npm install -g ctx7` — see https://context7.com/docs/clients/cli
#
# Caveman: https://github.com/JuliusBrussee/caveman — token-efficient skills; optional Claude Code plugin.
# Cavekit: https://github.com/JuliusBrussee/cavekit — spec/build pipeline (clone ~/.cavekit + install.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export FLAKE="${FLAKE:-$ROOT}"
# shellcheck source=common.sh
source "$FLAKE/scripts/shell/common.sh"

# Install find-docs skill + agent rules for CLI mode (non-MCP).
# Requires auth: run `ctx7 login` once, or set CONTEXT7_API_KEY (e.g. from sops).
setup_ctx7_cli() {
  print_header "CTX7 CLI (skills + rules)"
  if ! command_exists ctx7; then
    print_error "ctx7 not on PATH — run a home switch so llm.nix installs it."
    return 1
  fi

  local api_args=()
  if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
    api_args=(--api-key "$CONTEXT7_API_KEY")
  fi

  if [[ ${#api_args[@]} -eq 0 ]] && ! ctx7 whoami >/dev/null 2>&1; then
    print_error "Set CONTEXT7_API_KEY (e.g. open a login shell after switch) or run: ctx7 login"
    print_info "Then re-run: just post-install"
    return 1
  fi

  print_info "ctx7 setup --cli (Claude Code, Cursor, OpenCode)…"
  ctx7 setup --cli --yes "${api_args[@]}" --claude
  ctx7 setup --cli --yes "${api_args[@]}" --cursor
  ctx7 setup --cli --yes "${api_args[@]}" --opencode
  print_success "Context7 CLI setup finished for Claude, Cursor, and OpenCode."
}

# Caveman: `npx skills add` for Cursor/Copilot/Windsurf/Cline/etc.; Claude Code plugin for hooks + bundled skills.
setup_caveman() {
  print_header "Caveman (skills + Claude plugin)"

  if command_exists npx; then
    print_info "npx skills add JuliusBrussee/caveman…"
    npx --yes skills add JuliusBrussee/caveman
    print_success "Caveman skills installed or updated (npx)."
  else
    print_error "npx not on PATH — add Node (e.g. dev tooling) to use the skills CLI."
  fi

  if command_exists claude; then
    print_info "Claude Code: caveman marketplace + plugin…"
    claude plugin marketplace add JuliusBrussee/caveman \
      || print_info "caveman marketplace: ignored if already added"
    claude plugin install caveman@caveman \
      || print_info "caveman plugin: ignored if already installed"
    print_success "Caveman Claude plugin steps finished."
  else
    print_info "claude CLI not on PATH — skipped plugin install (Claude Code only)."
  fi
}

main() {
  setup_ctx7_cli
  setup_caveman
  print_header "POST-INSTALL DONE"
}

main "$@"
