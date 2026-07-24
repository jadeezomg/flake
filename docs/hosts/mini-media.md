# Mini — media hosting (nixflix + dual playback)

Mini runs the **household media automation and playback stack** when
**`miniMediaHosting = true`** in `hosts/mini/host.nix`.

**Policy ADRs:**

| ADR | Decision |
|-----|----------|
| [0003](../adr/0003-dual-playback-plex-and-jellyfin.md) | Keep **both** Plex and Jellyfin |
| [0004](../adr/0004-media-automation-on-mini-payloads-on-unraid.md) | Automation on mini; library/downloads on Unraid NFS |
| [0005](../adr/0005-vpn-confined-downloaders-search-in-netns.md) | Downloaders in WireGuard netns; Search stays in-netns |
| [0006](../adr/0006-arr-single-data-readwritepaths-for-hardlinks.md) | Arr `ReadWritePaths=/data` so hardlinks work |

## Layout

```
miniMediaHosting
  → hosts/mini/default.nix
      inputs.nixflix.nixosModules.default   # upstream + vpn-confinement
      hosts/mini/services/media/
          storage.nix     # NFS mounts, unraid uid 99, sops.secrets
          nixflix/        # arr, downloaders, Jellyfin, remote-dir setup
          native.nix      # Plex, Seerr, Bazarr (nixflix seerr off)
          proxy.nix       # Caddy *.jadee.fyi → backends
```

`nixflix/` splits by domain: `default.nix` (enable/paths), `common.nix`,
`arr.nix`, `downloaders.nix`, `jellyfin.nix`, `setup.nix`.

Upstream nixflix **postgres / caddy / nginx / seerr** are disabled. We front
everything with mini’s Caddy `tsnet` snippet and run Seerr/Bazarr/Plex as
native NixOS services.

## Storage model

| Path | Source | Role |
|------|--------|------|
| `/data` | NFS `192.168.178.62:/mnt/user/data` | downloads + library root (RW for arr/downloaders) |
| `/data/media/Music` | NFS Unraid Music share | music library (nested mount) |
| `/media` | bind of `/data/media`, **ro** | playback view for Plex/Jellyfin |
| `/Music` | bind of Music | Lidarr/Jellyfin convenience path |
| `/srv/nixflix` | local 2 TB app SSD | service state (arr DBs, Jellyfin, Plex, …) |
| `/var/lib/qBittorrent` | local | qBittorrent state + search plugins |

Library owner: user **`unraid` (uid 99)** / group **`users` (gid 100)** so
files match Unraid’s share ownership.

`nixflix-setup-remote-dirs.service` creates expected torrent/usenet/media
subdirs on NFS before the stack starts.

## Services

### Automation (nixflix)

- **Sonarr / Radarr / Lidarr / Prowlarr** + **FlareSolverr**
- **qBittorrent** + **SABnzbd** with `vpn.enable` (Proton WireGuard from sops)
- **Jellyfin** — declarative libraries/users; Intel QSV on `renderD128`
  - Trickplay **off** (`enableTrickplayImageExtraction = false` in `nixflix/common.nix`) —
    NFS + full-library ffmpeg was multi-hour / multi-GB; not worth it on mini.

### Native extras

- **Plex** — same GPU; LAN discovery helpers on the home subnet only
- **Seerr** — request UI (`:5055`)
- **Bazarr** — subtitles (`:6767`) + English profile oneshot

### Public URLs (Caddy `tsnet`, node `mini-proxy`)

| Host | Backend |
|------|---------|
| `sonarr.jadee.fyi` | `127.0.0.1:8989` |
| `radarr.jadee.fyi` | `127.0.0.1:7878` |
| `lidarr.jadee.fyi` | `127.0.0.1:8686` |
| `prowlarr.jadee.fyi` | `127.0.0.1:9696` |
| `sabnzbd.jadee.fyi` | nixflix `connectionAddress:8080` (VPN netns) |
| `qbittorrent.jadee.fyi` | nixflix `connectionAddress:8282` (VPN netns) |
| `seerr.jadee.fyi` | `127.0.0.1:5055` |
| `bazarr.jadee.fyi` | `127.0.0.1:6767` |
| `jellyfin.jadee.fyi` | `127.0.0.1:8096` |
| `plex.jadee.fyi` | `127.0.0.1:32400` |

DNS for those names is maintained with `just dns-sync` (Cloudflare → Tailscale
IP of `mini-proxy`). Caddy alone does not create DNS records.

## Download / import / cleanup path

1. Arr grabs a release → qBittorrent or SABnzbd (both VPN-confined).
2. Download lands under `/data/torrents/…` or `/data/usenet/…` on NFS.
3. Arr hardlinks (or moves) into `/data/media/…` — **same filesystem** as
   downloads because both live under `/data` (see ADR-0006).
4. qBittorrent **`GlobalMaxRatio = 0`** + **`ShareLimitAction = Stop`** so
   finished torrents stop seeding immediately.
5. Arr **`removeCompletedDownloads`** then removes the *client job*; library
   files stay via the hardlink.

If imports fail with `EXDEV` / “Read-only file system”, check Arr
`ReadWritePaths` — it must be a **single** `/data` entry, not per-subdir
binds.

The same applies to **qBittorrent** (`ProtectSystem=strict`): grant
`ReadWritePaths=/data`, not `/data/torrents`, or new torrents error with
`file_open … Read-only file system` while the host mount is still RW.

## qBittorrent notes

**WebUI password.** sops `mini/media/qbittorrent/password` is the plaintext.
nixflix uses it for Arr→client auth. An `ExecStartPre` (root) derives
`WebUI\Password_PBKDF2` into the conf so the flake never stores the hash.
Proton Pass entry: **Nixflix — qBittorrent** → `https://qbittorrent.jadee.fyi/`.

**Search.** Stays inside the VPN netns (ADR-0005). Plugins under
`nova3/engines` are **manual** (WebUI). A thin non-setuid wrapper points
`pythonExecutablePath` at `python3.withPackages` (requests/bs4/lxml/…) and
strips qBittorrent’s `-I` so `PYTHONPATH` / nova3 helpers work.

**Stale VPN.** If Search returns empty but the daemon is up, check WireGuard
handshake age (`just mini vpn-status` / `wg show` in the netns). A dead peer
makes indexer HTTPS time out. Prefer `just mini vpn-restart` over a raw
`systemctl restart wg`:

- SABnzbd often hangs on stop when the tunnel is dead — the recipe SIGKILLs it.
- nixflix `wg-up` gates on **ICMP ping**; Proton peers commonly drop ping even
  when UDP/51820 is fine, so a stock restart can fail after teardown. The recipe
  installs a runtime ExecStart drop-in that probes UDP instead.
- Downloaders `BindsTo=wg.service` — wg must be active for them to stay up.

If handshake stays at `0 B received`, the Proton server in
`mini/media/vpn/wireguard-conf` is down (e.g. LU#12) — export a fresh WireGuard
profile for a healthy server into that sops secret, then `vpn-restart` again.

Other media ops: `just mini media-status`, `arr-restart`, `media-restart`,
`downloaders-restart`, `stack-restart`.

## Secrets

Canonical paths: `secrets/SCHEMA.md` § mini media. Declarations live in
`hosts/mini/services/media/storage.nix` (not a flat `media.nix`).

## Deploy / ops

```bash
# from any machine with the flake
just mini deploy          # pull origin/main on mini + nh switch
just dns-sync             # ensure *.jadee.fyi A records exist
```

Commit + **push** before deploy — mini pulls `origin/main`. After `.nix`
edits: `flake fmt`, `git add`, optional
`nix eval ".#nixosConfigurations.mini.config.system.build.toplevel.drvPath"`.

Remote shell on mini is **nushell**; prefer
`ssh mini 'bash -lc "…"'` for one-liners.
