#!/usr/bin/env bash
# Immich backup restore drill — prove the restic repo on Unraid is actually
# restorable, rather than merely green in systemd.
#
# An unverified backup is a rumour. Run this within a week of the initial seed
# and quarterly after. It is read-only: nothing in the repo or in /srv/immich is
# modified.
#
# Docs: docs/hosts/mini-immich.md § Backup
#
# Local (on mini):      bash scripts/shell/mini-immich-drill.bash
# Remote (workstation): just mini immich-backup-drill
set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
REMOTE=false
SAMPLE="${IMMICH_DRILL_SAMPLE:-20}"

for arg in "$@"; do
	case "$arg" in
	--remote) REMOTE=true ;;
	--local) ;;
	-h | --help)
		cat <<'USAGE'
Usage: mini-immich-drill.bash [--local|--remote]

Verifies the Immich restic backup end to end:
  1. restic check          — repo structure is sound
  2. DB dump verification  — newest dump in the REPO gunzips and is complete
  3. byte-compare          — N random originals streamed from the repo vs disk

Read-only. Set IMMICH_DRILL_SAMPLE to change the sample size (default 20).
USAGE
		exit 0
		;;
	*)
		printf 'unknown argument: %s (try --help)\n' "$arg" >&2
		exit 2
		;;
	esac
done

if [[ -n "${FLAKE:-}" && -f "${FLAKE}/scripts/shell/common.sh" ]]; then
	# shellcheck source=scripts/shell/common.sh
	source "${FLAKE}/scripts/shell/common.sh"
else
	print_header() { printf '\n━━ %s ━━\n' "$*"; }
	print_success() { printf '▲ %s\n' "$*"; }
	print_error() { printf '▼ %s\n' "$*"; }
	print_info() { printf '▪ %s\n' "$*"; }
fi

run_remote() {
	local target="${MINI_SSH:-mini}"
	print_header "IMMICH BACKUP DRILL (remote)"
	print_info "target=${target}"

	if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" 'exit 0' 2>/dev/null; then
		print_error "cannot reach ${target} over ssh (BatchMode)"
		print_info "set MINI_SSH=<host> to target a different address"
		exit 1
	fi

	ssh -t "$target" "IMMICH_DRILL_SAMPLE=${SAMPLE} bash -s -- --local" <"$SCRIPT_PATH"
}

section() { printf '\n━━ %s ━━\n' "$*"; }

run_local() {
	print_header "IMMICH BACKUP DRILL"

	if ! command -v restic-immich >/dev/null 2>&1; then
		print_error "restic-immich not on PATH — is miniImmich enabled and switched?"
		exit 1
	fi
	if [[ $EUID -ne 0 ]]; then
		print_error "must run as root (the repo password and /srv/immich are 0700)"
		exit 1
	fi

	local rc=0

	section "1/3  REPOSITORY STRUCTURE"
	if restic-immich check; then
		print_success "repo structure sound"
	else
		print_error "restic check FAILED"
		rc=1
	fi

	section "2/3  NEWEST DATABASE DUMP (streamed from the repo)"
	# `restic dump` streams a single file straight out of the repository, so this
	# verifies the backed-up copy rather than the local one — the whole point.
	local newest
	newest=$(restic-immich ls latest --tag immich 2>/dev/null |
		grep -E '/srv/immich/backups/immich-db-backup-.*\.sql\.gz$' | sort | tail -1)

	if [[ -z "$newest" ]]; then
		print_error "no immich-db-backup-*.sql.gz found in the newest snapshot"
		print_info "the nightly pg_dump may never have run — check restic-backups-immich"
		rc=1
	else
		print_info "verifying ${newest}"
		local dump
		dump=$(mktemp -t immich-drill.XXXXXX.sql.gz)
		if restic-immich dump latest --tag immich "$newest" >"$dump" 2>/dev/null && gzip -t "$dump"; then
			if gzip -cd "$dump" | tail -n 5 | grep -q '^-- PostgreSQL database dump complete'; then
				local tables
				tables=$(gzip -cd "$dump" | grep -c '^CREATE TABLE ' || true)
				print_success "dump is complete and well-formed (${tables} CREATE TABLE statements)"
			else
				print_error "dump is TRUNCATED — no completion marker"
				rc=1
			fi
		else
			print_error "could not stream or gunzip the dump from the repo"
			rc=1
		fi
		shred -u "$dump" 2>/dev/null || true
	fi

	section "3/3  BYTE-COMPARE ${SAMPLE} RANDOM ORIGINALS"
	local checked=0 failed=0 f
	while IFS= read -r f; do
		checked=$((checked + 1))
		if restic-immich dump latest --tag immich "$f" 2>/dev/null | cmp -s - "$f"; then
			printf '  ok    %s\n' "$f"
		else
			printf '  FAIL  %s\n' "$f"
			failed=$((failed + 1))
		fi
	done < <(find /srv/immich/library /srv/immich/upload -type f 2>/dev/null | shuf -n "$SAMPLE")

	if ((checked == 0)); then
		print_error "no originals found under /srv/immich/{library,upload} to compare"
		rc=1
	elif ((failed > 0)); then
		print_error "${failed}/${checked} originals differ from the backup"
		rc=1
	else
		print_success "${checked}/${checked} originals byte-identical to the backup"
	fi

	section "RESULT"
	if ((rc == 0)); then
		print_success "drill passed — the backup is restorable"
	else
		print_error "drill FAILED — investigate before trusting this backup"
	fi
	return "$rc"
}

if [[ "$REMOTE" == true ]]; then
	run_remote
else
	run_local
fi
