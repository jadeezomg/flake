# 0006 — Arr services get a single `/data` ReadWritePaths entry

**Status:** accepted (2026-07-22)

Sonarr/Radarr/Lidarr must **hardlink** (or atomically move) from download dirs into the library. Both live under the Unraid NFS tree at `/data`. Under `ProtectSystem=strict`, listing **separate** `ReadWritePaths` for e.g. `/data/torrents` and `/data/media` makes systemd bind-mount each path — on NFS that remounts `/data` read-only for some views and splits the tree across mounts, so hardlinks fail with **`EXDEV`** / “Read-only file system.”

**Decision:** force a **single** `ReadWritePaths = [ "/data" ]` (plus state dirs as needed) on the Arr units so download and library stay one writable filesystem namespace.

## Coupled decisions

**Import before remove.** Arr `removeCompletedDownloads` only clears client jobs after a successful import **and** after seeding goals. qBittorrent therefore sets **`GlobalMaxRatio = 0`** and **`ShareLimitAction = Stop`** so finished torrents stop immediately and Arr can delete the job while hardlinked library files remain.

## Rejected alternatives

1. **Copy instead of hardlink** — doubles disk use on Unraid and slows imports.
2. **Weaken `ProtectSystem`** globally — larger sandbox hole than one wide data path.
3. **Local download disk + copy to NFS** — reintroduces dual storage and copy cost.

## Out of scope

Per-Arr category path redesign; usenet TBA/queue edge cases unrelated to hardlinks.
