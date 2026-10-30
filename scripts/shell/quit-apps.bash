#!/usr/bin/env bash
# Quit the open macOS apps before a switch, so the activation does not replace
# an app while it runs. Each app gets a normal quit request, as with Cmd+Q: an
# app with unsaved work asks first, and nothing is force-quit. Terminals,
# Finder, menu bar apps and the apps that run this script stay open.
# `--dry-run` lists the apps without quitting them.
set -euo pipefail

source "${FLAKE:-${HOME}/git/flake}/scripts/shell/common.sh"

if ! is_darwin; then
  print_error "quit-apps only applies on Darwin"
  exit 1
fi

dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

# The process chain of this script: an editor or terminal that runs it stays open.
ancestors=()
pid=$$
while [[ "$pid" -gt 1 ]]; do
  ancestors+=("$pid")
  pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done

# Prints "pid<TAB>name" for each app it asked to quit (or would ask).
apps=()
while IFS= read -r line; do
  [[ -n "$line" ]] && apps+=("$line")
done < <(osascript -l JavaScript - "$dry_run" "${ancestors[@]}" <<'JS'
ObjC.import('AppKit');
function run(argv) {
  const dryRun = argv[0] === 'true';
  const keepPids = new Set(argv.slice(1).map(Number));
  // Under herdr the shell's process chain does not pass through the
  // terminal app, so terminals stay open by bundle ID.
  const keepIds = new Set([
    'com.apple.finder',
    'net.kovidgoyal.kitty',
    'com.mitchellh.ghostty',
    'com.apple.Terminal',
    'com.googlecode.iterm2',
    'com.github.wez.wezterm',
  ]);
  const running = $.NSWorkspace.sharedWorkspace.runningApplications;
  const asked = [];
  for (let i = 0; i < running.count; i++) {
    const app = running.objectAtIndex(i);
    // The bridge returns these numbers as strings.
    const pid = Number(app.processIdentifier);
    // 0 = NSApplicationActivationPolicyRegular: apps with a Dock icon.
    if (Number(app.activationPolicy) !== 0) continue;
    if (keepIds.has(ObjC.unwrap(app.bundleIdentifier)) || keepPids.has(pid)) continue;
    // terminate (not forceTerminate) is the soft quit request.
    if (dryRun || app.terminate) asked.push(pid + '\t' + ObjC.unwrap(app.localizedName));
  }
  return asked.join('\n');
}
JS
)

if [[ ${#apps[@]} -eq 0 ]]; then
  print_success "No open apps to quit"
  exit 0
fi

names=$(printf '%s\n' "${apps[@]}" | cut -f2 | paste -sd ',' - | sed 's/,/, /g')
if $dry_run; then
  print_info "Would quit: $names"
  exit 0
fi
print_pending "Asked to quit: $names"

# Wait up to 30 s. An app that is still open most likely shows a save dialog.
open=()
for _ in $(seq 30); do
  open=()
  for app in "${apps[@]}"; do
    kill -0 "${app%%$'\t'*}" 2>/dev/null && open+=("${app#*$'\t'}")
  done
  [[ ${#open[@]} -eq 0 ]] && break
  sleep 1
done

if [[ ${#open[@]} -eq 0 ]]; then
  print_success "All apps quit"
else
  print_info "Still open, for example waiting on a save dialog: ${open[*]}"
fi
