# 0005 — VPN-confined downloaders; Search stays in the netns

**Status:** accepted (2026-07-22)

qBittorrent and SABnzbd run under nixflix **`vpn-confinement`** (Proton WireGuard from sops `mini/media/vpn/wireguard-conf`). The whole service cgroup gets `NetworkNamespacePath=/run/netns/wg`, so **children inherit the VPN** — including qBittorrent Search plugin processes. We **do not** escape Search to the host network.

## Why keep Search in-netns

Splitting “torrents on VPN / Search on host” needs either a **setuid `nsenter` helper** (weakens `PrivateUsers` / `NoNewPrivileges` / SUID restrictions) or a **host-netns proxy sidecar**. We built and then removed the setuid path: it worked, but the hardening cost and operational surface were not worth “Search works when the VPN peer is down.” Prefer fixing a stale WireGuard handshake over punching a host-netns hole.

## Coupled decisions

**Minimal search tooling still exists.** Plugins stay **manual** under `nova3/engines`. A non-privileged `python3.withPackages` wrapper strips qBittorrent’s `-I` and sets `PYTHONPATH` / `SSL_CERT_FILE` — bare system Python lacks plugin deps. No declarative plugin sync / sops enable-list.

**Caddy reaches VPN listeners via `connectionAddress`.** SABnzbd/qBittorrent WebUIs are not on loopback; `proxy.nix` reverse-proxies to nixflix’s netns address.

**Activation cleanup.** Leftover setuid launcher bins under `/var/lib/qBittorrent/bin/` are removed so old escapes cannot linger after deploy.

## Rejected alternatives

1. **Setuid nsenter + optional bwrap** — functional; rejected for privilege and complexity.
2. **Host-netns HTTP proxy for indexer GETs** — cleaner long-term sandbox story, more moving parts than we want today.
3. **Disable Search entirely** — unnecessary once the VPN peer is healthy.

## Out of scope

SABnzbd hang-on-stop during `wg` restart; automatic WireGuard keepalive / health alerts.
