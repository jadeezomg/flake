#!/usr/bin/env bash
# Mini media-stack maintenance (VPN / downloaders / *arr / playback).
#
# Local (on mini):   bash scripts/shell/mini-media.bash <cmd>
# Remote:            just mini <cmd>
#                    MINI_SSH=mini.quokka-qilin.ts.net bash ... --remote <cmd>
set -euo pipefail

# bash -s (remote pipe) has no BASH_SOURCE[0]; fall back for set -u.
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
REMOTE=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
  --remote) REMOTE=true ;;
  --local) ;;
  -h | --help)
    cat <<'USAGE'
Usage: mini-media.bash [--remote|--local] <command>

Commands:
  status              VPN + downloaders + arr + media snapshot
  vpn-status          WireGuard handshake / netns egress
  vpn-restart         Bounce wg (ICMP-bypass) + qBittorrent/SABnzbd
  downloaders-restart Restart qBittorrent + SABnzbd only
  arr-restart         Restart Sonarr/Radarr/Lidarr/Prowlarr/FlareSolverr
  media-restart       Restart Plex/Jellyfin/Bazarr/Seerr
  stack-restart       vpn-restart → arr-restart → media-restart
USAGE
    exit 0
    ;;
  *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]:-}"

if [[ -n "${FLAKE:-}" && -f "${FLAKE}/scripts/shell/common.sh" ]]; then
  # shellcheck source=scripts/shell/common.sh
  source "${FLAKE}/scripts/shell/common.sh"
else
  print_header() { printf '\n━━ %s ━━\n' "$*"; }
  print_success() { printf '▲ %s\n' "$*"; }
  print_error() { printf '▼ %s\n' "$*"; }
  print_info() { printf '▪ %s\n' "$*"; }
  print_pending() { printf '❖ %s\n' "$*"; }
fi

ARR_UNITS=(sonarr radarr lidarr prowlarr flaresolverr)
MEDIA_UNITS=(plex jellyfin bazarr seerr)
DOWNLOADER_UNITS=(qbittorrent sabnzbd)

run_remote() {
  local target="${MINI_SSH:-mini}"
  local cmd="${1:-status}"
  shift || true
  print_header "MINI MEDIA (${cmd}, remote)"
  print_info "target=${target}"
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" 'exit 0' 2>/dev/null; then
    print_error "cannot ssh to ${target}"
    exit 1
  fi
  # No -t: stdin is the script body. A forced TTY breaks bash -s piping.
  ssh "$target" "bash -s -- --local ${cmd} $*" <"$SCRIPT_PATH"
}

unit_line() {
  local u="$1"
  local state
  state="$(systemctl is-active "$u" 2>/dev/null || true)"
  printf '  %-14s %s\n' "$u" "${state:-unknown}"
}

vpn_status_local() {
  print_header "VPN / WG"
  unit_line wg
  if [[ -e /run/netns/wg ]]; then
    print_info "netns /run/netns/wg present"
    sudo ip netns exec wg wg show || true
    if sudo ip netns exec wg ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
      print_success "netns egress ok (ping 1.1.1.1)"
    else
      print_error "netns egress FAILED (ping 1.1.1.1) — stale/down peer?"
    fi
  else
    print_error "netns /run/netns/wg missing"
  fi
}

status_local() {
  vpn_status_local
  print_header "DOWNLOADERS"
  for u in "${DOWNLOADER_UNITS[@]}"; do unit_line "$u"; done
  print_header "ARR"
  for u in "${ARR_UNITS[@]}"; do unit_line "$u"; done
  print_header "MEDIA"
  for u in "${MEDIA_UNITS[@]}"; do unit_line "$u"; done
}

# Proton endpoints often drop ICMP. nixflix wg-up gates on ping and fails restart
# even when UDP/51820 works. Install a runtime ExecStart drop-in that probes UDP.
install_wg_udp_gate() {
  local real patched dropdir
  real="$(systemctl show wg.service -p ExecStart --value | sed -n 's/.*path=\([^ ;]*\).*/\1/p')"
  if [[ -z "$real" || ! -x "$real" ]]; then
    real="$(systemctl cat wg.service 2>/dev/null | sed -n 's#^ExecStart=\(/nix/store/[^ ]*wg-up[^ ]*\)#\1#p' | tail -n1 || true)"
  fi
  if [[ -z "$real" || ! -f "$real" ]]; then
    print_error "could not locate nixflix wg-up script"
    return 1
  fi
  if [[ "$real" == /run/mini-wg-up ]]; then
    real="$(ls -1 /nix/store/*-wg-up/bin/wg-up 2>/dev/null | tail -n1 || true)"
  fi
  if [[ -z "$real" || ! -x "$real" ]]; then
    print_error "could not locate store wg-up"
    return 1
  fi

  patched=/run/mini-wg-up
  sudo cp "$real" "$patched"
  sudo chmod 0755 "$patched"
  sudo python3 - "$patched" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = 'ping -c 1 "$EndpointIP" > /dev/null 2>&1 && { success=true; break; }'
repl = '/run/current-system/sw/bin/nc -zvu -w 3 "$EndpointIP" 51820 > /dev/null 2>&1 && { success=true; break; }'
if needle not in text:
    if repl not in text and "nc -zvu" not in text:
        raise SystemExit(f"ping probe not found in {path}")
else:
    path.write_text(text.replace(needle, repl, 1))
PY

  dropdir=/run/systemd/system/wg.service.d
  sudo mkdir -p "$dropdir"
  sudo tee "$dropdir/udp-gate.conf" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=${patched}
EOF
  sudo systemctl daemon-reload
  print_info "installed runtime wg UDP gate (${patched})"
}

stop_downloaders() {
  print_pending "stopping downloaders"
  sudo systemctl stop qbittorrent.service 2>/dev/null || true
  if systemctl is-active --quiet sabnzbd.service 2>/dev/null; then
    if ! sudo timeout 15 systemctl stop sabnzbd.service; then
      print_error "sabnzbd stop timed out — SIGKILL"
      sudo systemctl kill -s SIGKILL sabnzbd.service || true
      sleep 1
      sudo systemctl reset-failed sabnzbd.service || true
    fi
  fi
}

cleanup_wg_leftovers() {
  sudo systemctl stop wg.service 2>/dev/null || true
  sudo systemctl reset-failed wg.service 2>/dev/null || true
  # Prefer nixflix wg-down so iptables NAT chains (wg-prerouting) are removed.
  local wg_down
  wg_down="$(systemctl show wg.service -p ExecStopPost --value | sed -n 's/.*path=\([^ ;]*\).*/\1/p' || true)"
  if [[ -n "${wg_down:-}" && -x "$wg_down" ]]; then
    sudo "$wg_down" || true
  else
    sudo ip netns del wg 2>/dev/null || true
    sudo ip link del wg-br 2>/dev/null || true
    sudo ip link del veth-wg-br 2>/dev/null || true
    sudo iptables -t nat -F wg-prerouting 2>/dev/null || true
    sudo ip6tables -t nat -F wg-prerouting 2>/dev/null || true
    sudo iptables -t nat -X wg-prerouting 2>/dev/null || true
    sudo ip6tables -t nat -X wg-prerouting 2>/dev/null || true
  fi
}

wait_handshake() {
  local i hs
  for i in 1 2 3 4 5 6 7 8 9 10; do
    hs="$(sudo ip netns exec wg wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' || true)"
    if [[ -n "${hs:-}" && "$hs" != 0 ]]; then
      print_success "WireGuard handshake ok (epoch ${hs})"
      return 0
    fi
    sleep 1
  done
  print_error "no WireGuard handshake — peer down or stale Proton config?"
  sudo ip netns exec wg wg show || true
  return 1
}

vpn_restart_local() {
  print_header "VPN RESTART"
  stop_downloaders
  install_wg_udp_gate
  cleanup_wg_leftovers
  print_pending "starting wg.service"
  if ! sudo systemctl start wg.service; then
    print_error "wg.service failed to start"
    journalctl -u wg.service -n 40 --no-pager || true
    return 1
  fi
  wait_handshake || true
  if sudo ip netns exec wg ping -c 2 -W 3 1.1.1.1; then
    print_success "netns egress ok"
  else
    print_error "netns still has no egress — export a fresh Proton WG conf for a healthy server into sops mini/media/vpn/wireguard-conf"
  fi
  ensure_media_mounts
  print_pending "starting downloaders"
  start_units "${DOWNLOADER_UNITS[@]}"
  unit_line wg
}

nfs_path_ok() {
  # Returns 0 when path is readable (not a stale NFS handle).
  local path="$1"
  timeout 5 ls "$path" >/dev/null 2>&1
}

# storage.nix mounts /media as a DIRECT NFS export, deliberately NOT a bind of
# /data/media — a bind shares /data's superblock and inherits its dead handle when
# /data expires (see the comment in hosts/mini/services/media/storage.nix).
# NFS binds still report fsType nfs4 in findmnt/What=, so detect the drift by
# superblock instead: a direct mount of a different export has its own device
# number, a bind of /data/media reuses /data's.
own_superblock() {
  local path="$1" parent="$2" pd cd
  pd="$(stat -c '%d' "$parent" 2>/dev/null || true)"
  cd="$(stat -c '%d' "$path" 2>/dev/null || true)"
  [[ -n "$cd" && -n "$pd" && "$cd" != "$pd" ]]
}

# /Music and /data/media/Music are the same export (/mnt/user/Music), so NFS
# shares one superblock between them and a device check cannot distinguish a
# bind there — readability (checked by nfs_path_ok) is all we can assert.
topology_ok() {
  case "$1" in
  media.mount) own_superblock /media /data ;;
  *) return 0 ;;
  esac
}

ensure_media_mounts() {
  # Nested NFS (/data/media/Music) goes stale after parent /data remounts.
  # ProtectSystem=strict services then fail NAMESPACE with "Stale file handle"
  # even when systemctl still reports the mount unit active.
  # Also repair topology drift: /media and /Music must be binds, not direct NFS.
  local need_remount=false

  if ! systemctl is-active --quiet data.mount || ! nfs_path_ok /data; then
    need_remount=true
  elif ! systemctl is-active --quiet data-media-Music.mount || ! nfs_path_ok /data/media/Music; then
    need_remount=true
  elif ! systemctl is-active --quiet Music.mount || ! nfs_path_ok /Music; then
    need_remount=true
  elif ! systemctl is-active --quiet media.mount || ! nfs_path_ok /media || ! topology_ok media.mount; then
    need_remount=true
  elif findmnt /media/Music >/dev/null 2>&1; then
    # Leftover from ad-hoc NFS remount of /media; Music is nested via /data/media/Music.
    need_remount=true
  fi

  if [[ "$need_remount" != true ]]; then
    return 0
  fi

  print_pending "repairing stale/missing/drifted NFS mounts"
  # Consumers hold mounts open; stop the ones that BindPaths=/ReadWritePaths NFS roots.
  stop_downloaders
  sudo systemctl stop \
    sonarr.service radarr.service lidarr.service prowlarr.service \
    bazarr.service jellyfin.service plex.service \
    2>/dev/null || true
  # Stop the automount units first. umount -lf under a live automount hangs up the
  # autofs pipe and leaves the .automount unit failed ("unmounted by someone else").
  sudo systemctl stop \
    media.automount Music.automount data-media-Music.automount data.automount \
    2>/dev/null || true
  sudo systemctl stop media-Music.mount Music.mount media.mount data-media-Music.mount 2>/dev/null || true
  sudo umount -lf /media/Music 2>/dev/null || true
  sudo umount -lf /Music 2>/dev/null || true
  sudo umount -lf /media 2>/dev/null || true
  sudo umount -lf /data/media/Music 2>/dev/null || true
  sudo umount -lf /data 2>/dev/null || true
  sleep 1
  local m
  for m in data.mount data-media-Music.mount Music.mount media.mount media-Music.mount \
    data.automount data-media-Music.automount Music.automount media.automount; do
    sudo systemctl reset-failed "$m" 2>/dev/null || true
  done
  # Automount before mount: systemd refuses to set up an automount on a path that
  # is already a mount point, so starting the .mount first strands the .automount.
  sudo systemctl start data.automount 2>/dev/null || true
  sudo systemctl start data.mount
  sleep 1
  sudo systemctl start data-media-Music.automount Music.automount media.automount 2>/dev/null || true
  sudo systemctl start data-media-Music.mount Music.mount media.mount
  if ! nfs_path_ok /data || ! nfs_path_ok /media; then
    print_error "NFS remount still stale — check Unraid export / network"
    return 1
  fi
  if ! topology_ok media.mount; then
    print_error "mount topology still drifted from fstab (/media must be its own NFS export, not a bind of /data/media)"
    findmnt /media || true
    findmnt /data || true
    return 1
  fi
  print_success "NFS mounts healthy"
}

start_units() {
  local units=("$@")
  local u
  for u in "${units[@]}"; do
    sudo systemctl reset-failed "${u}.service" 2>/dev/null || true
  done
  sudo systemctl start "${units[@]/%/.service}"
  for u in "${units[@]}"; do unit_line "$u"; done
}

downloaders_restart_local() {
  print_header "DOWNLOADERS RESTART"
  ensure_media_mounts
  stop_downloaders
  start_units "${DOWNLOADER_UNITS[@]}"
}

arr_restart_local() {
  print_header "ARR RESTART"
  ensure_media_mounts
  start_units "${ARR_UNITS[@]}"
}

media_restart_local() {
  print_header "MEDIA RESTART"
  ensure_media_mounts
  start_units "${MEDIA_UNITS[@]}"
}

stack_restart_local() {
  vpn_restart_local
  arr_restart_local
  media_restart_local
  status_local
}

cmd="${1:-status}"
shift || true

if [[ "$REMOTE" == true ]]; then
  run_remote "$cmd" "$@"
  exit 0
fi

case "$cmd" in
status) status_local ;;
vpn-status) vpn_status_local ;;
vpn-restart) vpn_restart_local ;;
downloaders-restart) downloaders_restart_local ;;
arr-restart) arr_restart_local ;;
media-restart) media_restart_local ;;
stack-restart) stack_restart_local ;;
*)
  print_error "unknown command: $cmd"
  exit 2
  ;;
esac
