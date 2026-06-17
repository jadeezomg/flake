# Task 5 — Phase 4: nixflix media stack (BLOCKED on decisions)

**State:** not started; **independent** of the agent/memory work. Researched only.

## What it is
`github:kiriwalawren/nixflix` (MPL-2.0) — declarative NixOS media server: Jellyfin + arr stack (Sonarr/Radarr/Lidarr/Prowlarr/Seerr), qBittorrent, optional PostgreSQL backend, **WireGuard VPN confinement** (via its `vpn-confinement` input), nginx/Caddy reverse proxy, theme.park theming, TRaSH-guide defaults. Exposes `nixosModules.default` (alias `.nixflix`).

## Implementation sketch (once unblocked)
- Add `nixflix` + its `vpn-confinement` input to `flake.nix` (`inputs.nixpkgs.follows`).
- Gate behind a new toggle (e.g. `miniMediaHosting`) in `hosts/mini/host.nix`; new module `hosts/mini/services/nixflix.nix` importing `inputs.nixflix.nixosModules.default`.
- Configure media/state dirs, the arr services, VPN confinement for the torrent path, and tailnet exposure (likely `tailscale serve` like the other UIs).

## BLOCKERS — decide before building (open in the plan)
1. **Host it on mini at all?** mini is the LLM/agent box — media may belong on a different host.
2. **Media storage location** — check mini's disko layout / free space (`hosts/mini/disko.nix`); media needs lots of disk.
3. **VPN provider** for the torrent/arr path.
4. Which arr services + indexers.

## Suggested skills
- `Plan` (architect the storage/VPN/exposure design) or `grill-with-docs` to resolve the blockers, then implement. `flake-structure` for input wiring.
