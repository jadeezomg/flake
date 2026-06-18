#!/usr/bin/env bash
# Reconcile Cloudflare DNS with mini's Caddy vhosts.
#
# The "registry" is the Caddy vhost set itself (single source of truth) — every
# host under `services.caddy.virtualHosts` on the mini config should have an A
# record pointing at the mini-proxy tailnet node. This reads that list from the
# flake, finds the node's Tailscale IP, and creates any missing A records via
# flarectl (Cloudflare CLI). Existing records are reported; a record that exists
# with the wrong type/content is flagged (never silently overwritten).
#
# Runs locally (needs your tailnet view + sops editor key), not over SSH.
#   flake mini dns-sync                  # or: bash scripts/shell/dns-sync.bash
# Env overrides: DNS_ZONE, DNS_NIXHOST, DNS_TS_NODE.
set -euo pipefail
source "${FLAKE:?FLAKE unset — run via the 'flake' wrapper}/scripts/shell/common.sh"

ZONE="${DNS_ZONE:-jadee.fyi}"
NIXHOST="${DNS_NIXHOST:-mini}"
TSNODE="${DNS_TS_NODE:-mini-proxy}"

print_header "DNS SYNC"
print_info "zone=${ZONE}  caddy-host=${NIXHOST}  tailnet-node=${TSNODE}"

command_exists flarectl || {
  print_error "flarectl not found — enable the devenv.cloud profile"
  exit 1
}
command_exists jq || {
  print_error "jq not found"
  exit 1
}

# Registry: Caddy vhost names from the flake (these are already FQDNs).
mapfile -t HOSTS < <(
  nix eval --json \
    "${FLAKE}#nixosConfigurations.${NIXHOST}.config.services.caddy.virtualHosts" \
    --apply builtins.attrNames | jq -r '.[]' | sort
)
[ "${#HOSTS[@]}" -gt 0 ] || {
  print_error "no caddy vhosts found in the ${NIXHOST} config"
  exit 1
}

# Target: the proxy node's IPv4 Tailscale address, from the local tailnet view.
IP="$(
  tailscale status --json | jq -r --arg n "$TSNODE" '
    ([.Self] + ((.Peer // {}) | to_entries | map(.value)))[]
    | select(.HostName == $n) | .TailscaleIPs[]? | select(test(":") | not)
  ' | head -1
)"
[ -n "$IP" ] || {
  print_error "tailnet node '${TSNODE}' not found in 'tailscale status' (node up? are you on the tailnet?)"
  exit 1
}
print_info "${TSNODE} -> ${IP}"

# Cloudflare token from sops (decrypts with your editor age key).
CF_API_TOKEN="$(sops decrypt --extract '["cloudflare_dns_api_token"]' "${FLAKE}/secrets/secrets.yaml")"
export CF_API_TOKEN

# Snapshot existing records: name -> "TYPE CONTENT". `flarectl dns list` prints
# `ID | TYPE | NAME | CONTENT | PROXIED | TTL`.
declare -A CUR=()
while IFS='|' read -r _id typ name content _rest; do
  typ="${typ//[[:space:]]/}"
  name="${name//[[:space:]]/}"
  content="${content//[[:space:]]/}"
  [ -n "$name" ] && CUR["$name"]="${typ} ${content}"
done < <(flarectl dns list --zone "$ZONE" 2>/dev/null)

rc=0
for h in "${HOSTS[@]}"; do
  entry="${CUR[$h]:-}"
  if [ -z "$entry" ]; then
    print_pending "creating  A  ${h} -> ${IP}"
    flarectl dns create --zone "$ZONE" --name "$h" --type A --content "$IP" >/dev/null
    print_success "created   ${h}"
  else
    typ="${entry%% *}"
    content="${entry#* }"
    if [ "$typ" = "A" ] && [ "$content" = "$IP" ]; then
      print_success "ok        ${h}  (A ${content})"
    else
      print_error "conflict  ${h}  exists as '${typ} ${content}', expected 'A ${IP}' — fix manually"
      rc=1
    fi
  fi
done

print_header "END"
exit "$rc"
