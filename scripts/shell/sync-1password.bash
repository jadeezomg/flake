#!/usr/bin/env bash
# Sync curated sops secrets into the 1Password "Employee" vault.
# Replaces the prior home-manager activation entry in sops-1password.nix
# (removed) — `op` auth is per-shell, so this is invoked manually after
# `op signin` from the same shell, or with the desktop app's CLI integration
# unlocked.
set -euo pipefail

source "${FLAKE:-${HOME}/.dotfiles/flake}/scripts/shell/common.sh"

if ! is_darwin; then
  print_error "sync-1password only applies on Darwin (Linux uses libsecret via sops-keyring.nix)"
  exit 1
fi

# Prefer the Homebrew `op` — the binary path the desktop-app CLI integration
# was authorized against. Falls back to whatever `op` is on PATH otherwise.
if [[ -x /opt/homebrew/bin/op ]]; then
  OP=/opt/homebrew/bin/op
elif command_exists op; then
  OP="$(command -v op)"
else
  print_error "op not found. Install 1Password CLI or enable Homebrew /opt/homebrew/bin/op."
  exit 1
fi

VAULT="Employee"

# 1Password item title → on-disk sops secret name (under ~/.config/sops-nix/secrets/)
# sops-nix on Darwin writes secrets to its canonical dir regardless of the
# per-secret `path = ...` override in home/shared/security.nix, so we read
# from there directly to avoid stale `/run/secrets/...` symlinks.
SECRETS_DIR="${HOME}/.config/sops-nix/secrets"
ITEMS=(
  "context7_api_key:${SECRETS_DIR}/context7-api-key"
  "github_token:${SECRETS_DIR}/agent-pat"
)

print_header "1PASSWORD SYNC"

if ! "$OP" whoami >/dev/null 2>&1; then
  print_error "op not signed in. Run 'op signin' (or unlock the 1Password desktop app and enable Settings → Developer → 'Integrate with 1Password CLI')."
  exit 1
fi

print_info "Syncing ${#ITEMS[@]} item(s) to vault: $VAULT"

rc=0
for entry in "${ITEMS[@]}"; do
  item="${entry%%:*}"
  path="${entry#*:}"

  if [[ ! -r "$path" ]]; then
    print_pending "skip $item — source missing: $path"
    continue
  fi

  val="$(tr -d '[:space:]' <"$path")"
  if [[ -z "$val" ]]; then
    print_pending "skip $item — source empty: $path"
    continue
  fi

  if "$OP" item get "$item" --vault "$VAULT" >/dev/null 2>&1; then
    if err="$("$OP" item edit "$item" --vault "$VAULT" "credential=$val" 2>&1 >/dev/null)"; then
      print_success "updated $item"
    else
      print_error "edit failed for $item: $err"
      rc=1
    fi
  else
    if err="$("$OP" item create --category 'API Credential' --vault "$VAULT" --title "$item" "credential=$val" 2>&1 >/dev/null)"; then
      print_success "created $item"
    else
      print_error "create failed for $item: $err"
      rc=1
    fi
  fi

  unset val err
done

print_header "END"
exit "$rc"
