# 0003 — Dual playback: Plex and Jellyfin on mini

**Status:** accepted (2026-07-22)

We run **both** Plex and Jellyfin on `mini` for playback. A 2026 ponytail audit flagged this as duplicate GPU/transcode stack (~160 lines of Nix + two Caddy vhosts); we **reject** consolidating to a single server. Plex and Jellyfin serve different client ecosystems and integration surfaces; the shared Arc Pro B50 transcode budget is an accepted operational cost, not a reason to drop either product.

## Coupled decisions

**Split ownership across modules.** Plex lives in `hosts/mini/services/media/native.nix` (`services.plex`, `unraid` user, `/srv/nixflix/plex`, Intel QSV via `/dev/dri/renderD128`, transcode tmp on `/srv/nixflix/plex-transcode`). Jellyfin is declared in `hosts/mini/services/media/nixflix/jellyfin.nix` via the nixflix module (`nixflix.jellyfin`, declarative users/libraries/encoding, same GPU). Both read the same library tree under `/media` (NFS from Unraid); download payloads stay under `/data` and are invisible to the players.

**Tailnet exposure via Caddy, not host firewall.** Neither server opens the NixOS firewall. Playback UIs are fronted on `plex.jadee.fyi` → `127.0.0.1:32400` and `jellyfin.jadee.fyi` → `127.0.0.1:8096` (`hosts/mini/services/media/proxy.nix`, `import tsnet`). Plex keeps LAN discovery helpers (GDM/SSDP) on the home subnet only — IPv4-only rules in `native.nix` so Plex is not advertised on global IPv6.

**Why keep Plex.** Existing Plex clients (TV apps, mobile, Plex Pass features), historical server state under `/srv/nixflix/plex`, and the `unraid` library UID model already tuned for Plex. Dropping Plex would force every household client to migrate and lose Plex-specific features (Live TV, Plexamp ecosystem, etc.) with no upside beyond line count.

**Why keep Jellyfin.** nixflix owns the declarative media stack (arr, downloaders, VPN confinement, Jellyfin users/API keys in sops). Jellyfin is the native playback target for that automation path; Seerr and the arr UIs assume a Jellyfin-shaped backend. Jellyfin is also the open-source, dashboard-first option for tailnet browsing without Plex account coupling.

**GPU contention is bounded, not eliminated.** Both can hardware-transcode on the same `renderD128` node. In practice concurrent transcodes are rare on a household server; if both saturate the GPU, tune one server to software transcode or cap simultaneous streams — do not delete a server to "free" the card.

## Rejected alternatives

1. **Plex only** — removes nixflix's first-class Jellyfin module, declarative libraries/users, and the playback path the arr stack was built around.
2. **Jellyfin only** — forces client migration off Plex and drops Plex Pass / client features the household still uses.
3. **Host toggles (`miniPlexEnable` / `miniJellyfinEnable`)** — adds configuration surface for a policy we have already decided: both stay on whenever `miniMediaHosting` is true.

## Out of scope / future work

1. **Automatic transcode arbitration** between Plex and Jellyfin on the B50 (cgroups, per-service stream limits). Revisit only if concurrent transcodes become routine.
2. **Library path unification** — today Plex and Jellyfin map slightly different folder sets in their respective configs; harmonize only when a library layout change is already planned.
3. **Replacing either server** — any future single-server migration needs its own ADR and a client-migration plan; this ADR does not authorize silent removal during complexity audits.
