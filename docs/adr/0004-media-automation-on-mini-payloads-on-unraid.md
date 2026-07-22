# 0004 — Media automation on mini; payloads on Unraid

**Status:** accepted (2026-07-22)

We host **arr / downloaders / playback UIs on `mini`**, but keep **download and library bytes on Unraid** over NFS (`192.168.178.62`). mini is the LLM/agent box with a small system SSD and a 2 TB app SSD for *state*; Unraid already holds the household media pool. Splitting compute from payload storage avoids duplicating terabytes onto mini and preserves Unraid as the share source of truth.

## Coupled decisions

**Mount shape.** `/data` is the NFS data share (RW). `/media` is a **read-only bind** of `/data/media` for players. Music is a nested NFS mount under `/data/media/Music` plus a `/Music` bind. Service state stays local under `/srv/nixflix` (and `/var/lib/qBittorrent`).

**UID bridge.** System user `unraid` (uid **99**) / group `users` (gid **100**) owns library writes so files land with Unraid-compatible ownership (`nixflix.globals.libraryOwner`).

**Toggle.** The whole stack is gated by `miniMediaHosting` in `hosts/mini/host.nix`.

## Rejected alternatives

1. **Local media on mini’s 2 TB** — insufficient for the library, and would fork a second copy away from Unraid shares.
2. **Run arr on Unraid** — abandons the declarative nixflix path and couples automation to the NAS OS.
3. **Object storage / mergerfs indirection** — extra moving parts for a single-homelab NFS share that already works.

## Out of scope

Hardening NFS auth (Kerberos, sec=sys assumptions), Unraid share layout redesign, and offline/caching mounts.
