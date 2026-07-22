[unraid-flash-diagnose.bash#0DC7]
1:#!/usr/bin/env bash
2:# Diagnose constant writes to the Unraid USB flash (/boot).
3:#
4:# Local (on Unraid):  bash scripts/shell/unraid-flash-diagnose.bash
5:# Remote (workstation): just unraid flash-diagnose
6:#                       UNRAID_SSH=root@192.168.178.62 bash ... --remote
7:set -uo pipefail
8:
9:SCRIPT_PATH="${BASH_SOURCE[0]}"
10:REMOTE=false
11:for arg in "$@"; do
12:	case "$arg" in
13:	--remote) REMOTE=true ;;
14:	--local) ;;
15:	-h | --help)
16:		cat <<'USAGE'
17:Usage: unraid-flash-diagnose.bash [--local|--remote]
…
24:USAGE
25:		exit 0
26:		;;
27:	esac
28:done
29:
30:if [[ -n "${FLAKE:-}" && -f "${FLAKE}/scripts/shell/common.sh" ]]; then
31:	# shellcheck source=scripts/shell/common.sh
32:	source "${FLAKE}/scripts/shell/common.sh"
33:else
34:	print_header() { printf '\n━━ %s ━━\n' "$*"; }
35:	print_success() { printf '▲ %s\n' "$*"; }
36:	print_error() { printf '▼ %s\n' "$*"; }
37:	print_info() { printf '▪ %s\n' "$*"; }
38:fi
39:
40:run_remote() {
41:	local target="${UNRAID_SSH:-root@jadee-server}"
42:	print_header "UNRAID FLASH DIAGNOSE (remote)"
43:	print_info "target=${target}"
44:
45:	if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" 'exit 0' 2>/dev/null; then
…
51:	fi
52:
53:	ssh -t "$target" 'bash -s -- --local' <"$SCRIPT_PATH"
54:}
55:
56:section() { printf '\n━━ %s ━━\n' "$*"; }
57:
58-171:run_local() { … }
172:
173:if [[ "$REMOTE" == true ]]; then
174:	run_remote
175:else
176:	run_local
177:fi

[…123ln elided; re-read needed ranges, e.g. /home/jadee/.dotfiles/flake/scripts/shell/unraid-flash-diagnose.bash:18-23,46-50]