# Task 5 — Phase 4: nixflix media stack

**State:** done & deployed (2026-07-22). This handoff is retained as a pointer only.

## Where to read instead

- Operator guide: [`docs/hosts/mini-media.md`](../hosts/mini-media.md)
- ADRs:
  - [0003 dual playback](../adr/0003-dual-playback-plex-and-jellyfin.md)
  - [0004 automation on mini / payloads on Unraid](../adr/0004-media-automation-on-mini-payloads-on-unraid.md)
  - [0005 VPN downloaders; Search in-netns](../adr/0005-vpn-confined-downloaders-search-in-netns.md)
  - [0006 Arr `/data` ReadWritePaths](../adr/0006-arr-single-data-readwritepaths-for-hardlinks.md)
- Code: `hosts/mini/services/media/` (toggle `miniMediaHosting` in `hosts/mini/host.nix`)

## Historical blockers (resolved)

1. Host on mini? **Yes** — automation/UIs on mini; bytes on Unraid NFS (ADR-0004).
2. Storage? Unraid NFS `/data` + local `/srv/nixflix` state.
3. VPN? Proton WireGuard via nixflix `vpn-confinement` (ADR-0005).
4. Arr set? Sonarr/Radarr/Lidarr/Prowlarr + FlareSolverr; Seerr/Bazarr/Plex native.
