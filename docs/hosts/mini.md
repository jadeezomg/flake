# Mini — operations & troubleshooting

Single reference for the `mini` host (Minisforum MS-01, headless NixOS).

**Scope:** only what is *not* readable from the flake. Every "what is configured"
question is answered by `hosts/mini/**` and the module tree; this file records the
ordering constraints, failure modes, one-time runtime steps and deliberate
decisions that the Nix code cannot express. When the two disagree, the flake wins
— fix this file.

---

## 1. Hardware & storage facts

| | |
|---|---|
| CPU / RAM | i5-12600H (4P+8E, vPro), 24 GB |
| GPU | discrete Intel Arc B50 (~15 GiB) + iGPU; needs `xe.force_probe=e223` |
| Disks | 256 GB NVMe (ESP + btrfs `@root @nix @home @var-log @snapshots`), 2 TB NVMe (btrfs → `/srv`) |
| NICs | 4 present, only `enp2s0f0np0` configured (`192.168.178.100/24`, gw `.1`) |
| OOB | Intel AMT 16.x, Client Control Mode |

Non-obvious:

- **`/tmp` is not tmpfs** (`boot.tmp.useTmpfs = false`, no `cleanOnBoot`). It is a
  plain directory on the btrfs root and **survives reboots**. Because btrfs is
  copy-on-write, `shred` there cannot reliably overwrite the original extent — put
  transient key material in **`/dev/shm`**. The only swap is zram (RAM), so nothing
  written to `/dev/shm` reaches disk. If a secret ever lands on `/tmp`, do not
  scrub it — rotate it.
- **No disk swap**, zram only (50%).
- `/nix` lives on the small 256 GB SSD → GC is deliberately aggressive
  (`daily`, `--delete-older-than 3d`).
- `buildCores = 2` — 24 GB is not much for a rebuild that also serves a 10 GB model.
- The 2 TB disk holds `/srv` only: `/srv/immich` (photo library) and
  `/srv/nixflix` (media service state). Media *payloads* are NFS from Unraid, not here.

## 2. Boot & SecureBoot

`secureBoot = false` today; lanzaboote is wired but inert.

**Enrollment order matters — two ways to break the box:**

1. `sudo sbctl create-keys` (creates `/var/lib/sbctl`)
2. flip `secureBoot = true` in `hosts/mini/host.nix`, commit
3. `just switch` → lanzaboote writes **signed** EFI files
4. `sudo sbctl verify` → every ESP entry must say signed
5. firmware → Security → *Reset to Setup Mode* / *Clear PK*
6. `sudo sbctl enroll-keys -m`
7. reboot, enable SecureBoot in firmware, `sudo sbctl status`

- Enabling lanzaboote **before** sbctl keys exist fails the switch (no PKI bundle).
- Enrolling keys **before** signed binaries are on the ESP makes the next boot fail.
- Without Setup Mode, `enroll-keys` fails or silently no-ops.
- **`-m` is not optional** — it imports Microsoft's KEK+DB; skip it and fwupd
  capsule updates are bricked.
- Recovery: clear all SecureBoot keys in firmware (back to Setup Mode), redo.

**`fwupd-refresh` makes `switch` return 4.** It races a restarting `fwupd.service`
/ LVFS and exits 1 (nixpkgs#288598, open). `hosts/mini/default.nix` forces
`SuccessExitStatus = [1 2]` behind an expiry guard (rechecks at fwupd ≥ 2.3). Run
`fwupdmgr refresh && fwupdmgr update` by hand when you actually want metadata.

Kernel is `cachyos-server` (not zen4) and Plymouth is off — both gated on
`server.enable`.

## 3. Network, DNS, firewall

- The firewall **trusts only `tailscale0`**; the sole public port is `:22`.
  Everything else (`:8000` llama.cpp, `:8080` open-webui, Caddy) is tailnet-only.
- **AMT ports `16992-16995` sit below the OS firewall** — `networking.firewall`
  cannot gate them; only AMT's own ACL does. AMT shares the NIC MAC with the OS.
  It is **LAN-only** — Tailscale cannot reach it (AMT is below the OS network
  stack). AMT-over-VPN would need a subnet router elsewhere; not done.
- Tailscale requires one interactive login once: `sudo tailscale up --ssh`.
- **Legacy `tailscale serve` mappings linger in `tailscaled` state** after the move
  to Caddy and keep answering on `mini.quokka-qilin.ts.net`. Clear once:
  `sudo tailscale serve reset` (then `tailscale serve status` → empty).

### Caddy / split-horizon DNS

Caddy joins the tailnet as its **own node `mini-proxy`** (caddy-tailscale plugin) so
it owns `:443` without colliding with mini's node. Certs come from the **Cloudflare
DNS-01** challenge, independent of the A records — issuance works before DNS exists.

- Cloudflare A records point at the **`mini-proxy` Tailscale IP**, **proxy OFF
  (grey cloud)** — Cloudflare cannot reach a private tailnet IP; the record only
  resolves the name.
- LAN clients without Tailscale need a **local DNS override** to
  `192.168.178.100` (`miniCaddyLanEnable` binds the LAN IP with the same certs).
  **Never point Cloudflare at the RFC1918 address** — that breaks off-LAN resolution.
- `just mini dns-sync` reconciles Cloudflare from the Caddy vhost set (the vhosts
  are the registry). It creates missing A records, reports existing ones, and
  **flags conflicts without overwriting** — a stale CNAME must be deleted by hand.
  Needs your tailnet view + sops editor key; CF token needs Zone:Read + DNS:Edit.
- The plugin Caddy build (caddy-tailscale + caddy-dns/cloudflare) is **uncached** —
  the first switch after a bump compiles it locally. Bump = update both pins and
  refresh `hash` via `lib.fakeHash`.

`environment.enableAllTerminfo` is on so `TERM=xterm-kitty` forwarded over SSH does
not break pagers/`systemctl`. On a pre-that generation use `kitty +kitten ssh`.

## 4. Secrets

Canonical paths: `secrets/SCHEMA.md`. Two different age keys live on mini:

| Key | Path | Used by |
|---|---|---|
| **host** key | `/var/lib/private/sops/age/keys.txt` | NixOS `sops.secrets` |
| **editor** key | `~/.config/sops/age/keys.txt` | Home Manager `sops-nix.service` |

**The host key alone is not enough** — HM decrypts user secrets with the same
editor key as your workstation, so it must be copied to mini (dir `0700`, file
`0600`) or `just switch` fails on the HM side. `just bootstrap-sops-host-key`
handles the host half; `just verify-sops-host-key mini` checks it.

Mini must be a recipient: `&mini` in `.sops.yaml` + `- *mini` under
`creation_rules`, then `sops updatekeys secrets/secrets.yaml`.

`mini/amt/password` is stored for recovery only — nothing consumes it declaratively.

## 5. Deploy & ops

```bash
just mini deploy        # git pull --ff-only on mini + nh switch (switch-fast)
just mini deploy-dry    # build only, no activation
just mini deploy-boot   # stage for next reboot (kernel/bootloader)
just mini pull / ssh / reboot / dns-sync
just mini llm <cmd>     # LLM service ops (nested module)
```

- **`deploy` pulls `origin/main`** — commit *and push* first, or you deploy the old tree.
- `deploy` uses `switch-fast` (no flake check, no commit on mini) since you authored
  upstream. Run `deploy-dry` first when you want a pre-flight build.
- **Author changes locally, never over SSH on mini.** Remote is inspect/deploy only.
- `flake fmt` after `.nix` edits, `git add -A` before any eval — flakes only see
  tracked files.
- **Mini's login shell is nushell** — for one-liners use `ssh mini 'bash -lc "…"'`.
- `just mini …` recipes are a `just` module (`just/mini.just`, `just/mini-llm.just`),
  so they appear as `mini::…` and show on **every** host. `just --list mini`,
  `just --list mini llm`.
- Host is reached **by address, not name** (`sshAddress = 192.168.178.100`) because
  it is headless and ops must work before name resolution does. Off-LAN:
  `MINI_SSH=mini.quokka-qilin.ts.net`.

## 6. LLM stack (`miniLlmHosting`)

One unit, **`llama-cpp`**: `llama-server` in **router mode** on `:8000`
(`--models-preset <generated INI> --models-max 2`, both models resident, no swap
latency). INI section name = the OpenAI model id. The unit comes from the shared
module `modules/profiles/llm/serve.nix` (`dotfiles.profiles.llm.serve`); mini's
models and knobs live in `hosts/mini/services/llm/default.nix`.

| Preset | Model | Notes |
|---|---|---|
| `local-chat` | `unsloth/gemma-4-12B-it-qat-GGUF` `UD-Q4_K_XL` | vision on (`mmproj-auto`), 128K total ctx / 2 slots → **64K per conversation**, KV `q8_0` |
| `local-embed` | `mradermacher/F2LLM-v2-0.6B-GGUF` `Q8_0` | 1024-dim, last-token pooling, `/v1/embeddings` |

- **`UD-Q4_K_XL` is the only quant that exists** for the QAT repo — higher precision
  *degrades* quantization-aware-trained weights. There is nothing to upgrade to.
- VRAM budget on 15 GiB: QAT 6.7 + mmproj 1 + embedder 0.6 + overhead 1.5 ≈ 9.8 GB,
  leaving ~5.2 GB for chat KV. Gemma 4 is cheap on KV (only 8 of 48 layers are full
  attention) ≈ 32 KiB/token at q8_0. Verify with `journalctl` (prints KV size) and
  `intel_gpu_top`. `--models-max 1` trades residency for max chat context.
- First boot downloads ~10 GB into **`/var/lib/llama-cpp/huggingface`** (HF token
  from sops `hf_token`).
- **MTP (speculative decoding, ~1.5–2.2× generation) is not configured.** The old
  blocker — missing `gemma4-assistant` draft-arch loader — is resolved in the pinned
  llama.cpp. To enable, add to the `[local-chat]` preset:
  `spec-type = draft-mtp` / `spec-draft-n-max = 2` (range 1–6). `hf-repo`
  auto-discovers the repo's bundled drafter; budget **+2 GB** and verify the server
  comes up — a drafter failure kills the whole preset.
- The `llama-cpp` build follows the GPU trait (`dotfiles.hardware.gpu = "intel"`
  → Vulkan). nixpkgs builds Vulkan or CUDA here — not SYCL, not OpenVINO (those
  need custom CMake + Intel stacks). `dotfiles.profiles.llm.llamaCppBackend`
  overrides the derived backend. Pick the GPU with `llm.serve.device`
  (→ `LLAMA_ARG_DEVICE`) or, without a rebuild, `sudo systemctl edit llama-cpp`
  → `Environment=LLAMA_ARG_DEVICE=…`. List ids with `llama-server --list-devices`.
- **No auth on `:8000`** — safe only because of the tailnet-only firewall. Any
  tailnet peer (IDEs, agents) points its OpenAI base URL at `http://mini:8000/v1`;
  no SSH tunnel. Open WebUI is loopback `:8080` behind `chat.jadee.fyi`; the first
  account created becomes admin.

Troubleshooting:

| Symptom | Action |
|---|---|
| Silence / very slow | `just mini llm status` — it prints the running command and **flags drift from the flake**. Drifted → `git add -A && just switch`, restart. Smoke tests: `max_tokens: 8`. |
| `jq` prints nothing | Never pipe SSE into `jq`; use `"stream": false` or read raw. |
| HTTP/TLS errors | Confirm `/v1/models` first, then `just mini llm logs`. |
| Live view | `just mini llm gpu` (`intel_gpu_top`) beside the journal — there is no built-in HTTP dashboard. |

`just mini llm bench` (llama-benchy) runs from any host. It exports
`LD_LIBRARY_PATH` at nix-ld's lib dir because uv's standalone Python bypasses the
nix-ld loader and PyPI wheels then cannot find `libstdc++`. Keep
`MINI_BENCH_CONCURRENCY` ≤ the server's slot count (2) — beyond that you measure
queueing. The tokenizer repo must be the **safetensors source** repo (GGUF repos
ship no HF tokenizer), else counts fall back to gpt2.

## 7. Immich (`miniImmich`)

Library on mini's local NVMe, Unraid is the backup target (ADR-0007).
`/srv/immich` (`0700 immich:immich`) is `IMMICH_MEDIA_LOCATION`; postgres and redis
talk over unix sockets, so **Immich itself needs no secret** — only the backup job has
credentials.

- **Postgres major is pinned to 17** and this is the host's only cluster. The
  on-disk format is permanent: a future bump is a manual offline `pg_upgrade`, not
  a rebuild. Every future service on mini inherits this cluster and this pin.
- **`services.immich.settings = null` is deliberate.** Any attrset flips Immich into
  `IMMICH_CONFIG_FILE` mode and **greys out the whole admin settings page**. Storage
  template, job concurrency, transcoding, external domain all live in the DB.
- **`nix flake update` can move Immich to a new major**, which runs irreversible
  migrations on next start. Read release notes, take a manual dump first.
- **GPU is off by default and enabling it buys video transcoding only** — nixpkgs
  has no OpenVINO `immich-machine-learning`, so CLIP/face inference stays on CPU
  either way. The module does not add the `render`/`video` groups for you.
- **`immich-cli` must match the server major** (`nix shell nixpkgs#immich-cli` from
  the same nixpkgs — never the npm build). Uploads are checksum-deduplicated, so
  re-runs are safe.
- After first login set **Admin → Settings → General → External Domain** to
  `https://immich.jadee.fyi` or shared links generate wrong addresses.

**Best single health signal:** natural-language search ("beach sunset"). It
exercises CLIP embeddings through vchord's index under NixOS's `search_path` — if
that works the whole vector stack is fine. If search is empty while job queues are
drained, reindex:

```sh
sudo -u postgres psql -d immich \
  -c 'REINDEX INDEX CONCURRENTLY clip_index; REINDEX INDEX CONCURRENTLY face_index;'
```

`postgresql-setup` only REINDEXes when an *already-installed* vchord changes
version — it never fires on a fresh database.

### Backup (restic → Unraid `sftp:root@192.168.178.62:/mnt/user/backup/immich`)

| Unit | When | Job |
|---|---|---|
| `restic-backups-immich` | 03:15 daily | `pg_dump` as `backupPrepareCommand`, then snapshot `/srv/immich` |
| `restic-backups-immich-maint` | 1st Sunday 04:30 | `forget --prune` (14d/8w/12m/3y) + `check --read-data-subset=5%` |
| `immich-backup-watchdog` | 09:00 daily | asks the **repository** whether a snapshot < 36 h old exists |

- The dump is a `backupPrepareCommand`, so **a failed dump aborts the snapshot** —
  media is never stored without a matching database. It is gated on `gzip -t` plus
  `pg_dump`'s completion marker and published by atomic `mv` from `.part`.
- The watchdog is not redundant with `OnFailure=`: a green timer proves nothing if
  the unit was masked, mini was off for a week, or the repo was replaced.
- **Never add `/var/lib/postgresql` to the restic paths.** A filesystem copy of a
  live `$PGDATA` is torn pages plus mid-stream WAL, version-locked to the exact
  `vchord.so` in the store at that instant. The dump is the backup.
- Sizing: photos are incompressible and do not dedup — budget **2×** the source.
  Derived data (`thumbs/`, `encoded-video/`) is included on purpose so a bare-metal
  restore is browsable immediately. Watch for an Immich upgrade that regenerates
  thumbnails — it rewrites all derived data in one night.
- Unraid one-time: generate the keypair on mini **in `/dev/shm`** (see §1), paste the
  public half via the **WebGUI** (Unraid's `/root` is tmpfs — a hand-appended
  `authorized_keys` does not survive reboot); share `backup` with cache/SMB/NFS all
  **off**; set Disk Settings → `md_write_method` = **reconstruct write** (parity
  read/modify/write caps the seed at ~40–80 MB/s vs ~100–130).
- Restore: `restic-immich restore latest --target / --include /srv/immich --sparse
  --verify`, then `chown -R immich:immich /srv/immich && chmod 0700`, then restore
  the DB from `/srv/immich/backups/`. Nothing about the repo is mini-specific — any
  host with an age key can decrypt `mini/backup/{restic-password,unraid-ssh-key}`.
- **An unverified backup is a rumour**: `just mini immich-backup-drill` within a week
  of the seed and quarterly after (checks repo, verifies newest dump, byte-compares
  20 random originals out of the repository).

Ops: `just mini immich-{status,logs,restart,du,users,vectors}` and
`immich-backup-{status,now,snapshots,check,drill,mount,unlock}`.

## 8. Media stack (`miniMediaHosting`)

Automation on mini, payloads on Unraid NFS (ADR-0004). Upstream nixflix
postgres/caddy/nginx/seerr are **disabled** — mini's Caddy fronts everything and
Seerr/Bazarr/Plex run as native NixOS services.

Quality profiles are in Nix. Recyclarr syncs them every day from
`hosts/mini/services/media/nixflix/quality.nix`. Do not edit them in the UI,
because the next sync replaces your edits. A cleanup unit deletes all other
profiles and moves their media to `Original + EN Subs`.

| Profile | Required audio | Bonus |
|---|---|---|
| Original + EN Subs | original language | English subtitles in the release name. Default in Seerr. |
| German Audio | German | original audio track too (dual audio) |
| PT-BR Audio + Subs | Portuguese (Brazil) | original audio track, PT-BR subtitles in the release name |

All three profiles use the same ladder: efficient 4K, then 1080p, then
high-bitrate 4K, then 720p. All 720p-2160p qualities are in one quality group,
so the custom format score sets this order. In Radarr, efficient 4K is 15 GB or
less, 1080p is 5-12 GB, and 720p is 2-8 GB. In Sonarr, the Size condition
measures a full season pack, so efficient 4K means AV1 or HEVC instead. Bazarr
gets the English subtitles after the download.

Library scans run in one daily window at 06:30
(`hosts/mini/services/media/library-scan.nix`). Plex and Jellyfin have no
periodic scan of their own, because the Arr apps report each import to them.
Unpackerr extracts torrent downloads that arrive as RAR archives
(`unpackerr.nix`).

Lidarr monitors nothing. On 2026-10-26 all artists and albums were set to
unmonitored, and new albums of an artist to `none`. Lidarr grabs only what you
monitor or search for by hand. The metadata profile (`lidarr-profiles.nix`)
still limits it to albums and EPs.

SABnzbd has `pre_check` off (`nixflix/downloaders.nix`). nixflix turns it on.
It asks the server for every article of a job before the download starts, one
job at a time. On 2026-10-26 the full queue sat in "Checking" for hours.

The media state is backed up every night at 04:15 (`media/backup.nix`): restic
over SFTP to `/mnt/user/backup/media` on Unraid, with the Immich backup's ssh
alias and password. Artwork, metadata caches, and logs are not included.

Notifications go through ntfy at https://ntfy.jadee.fyi (tailnet,
`hosts/mini/services/ntfy.nix`). The `media` topic gets imports and health
issues from the Arr apps. The `system` topic gets failed units through
`ntfy-alert@`. On the phone, add the server and log in as `jadee` with
`sops -d --extract '["mini"]["ntfy"]["jadee-password"]' secrets/secrets.yaml`.

Playback reads through mini's SSD (`hosts/mini/services/media/playback-cache.nix`).
The `/mnt/library` mount uses FS-Cache (`fsc`), with a 200 GiB cache in a sparse
ext4 image at `/srv/fscache.img`. When Plex or Jellyfin start a file of 80 GiB or
less, `media-prefetch` reads it once. The Unraid disk then delivers it in one
burst and can spin down while the file plays from the SSD. A change to the
`/mnt/library` mount options needs a reboot (`just mini deploy-boot`), because NFS
cannot change `fsc` on a remount.

The custom formats are not in the TRaSH guide. Nix writes them as JSON files,
and Recyclarr reads them through a `custom-formats` resource provider. The Seerr
request settings (default profile, season picker, specials, TVDB metadata) are
in `hosts/mini/services/media/seerr.nix`. Before each start, the `preStart` of
Seerr finds the default profile ID by name and merges the settings into
`settings.json`.

| Path | What |
|---|---|
| `/data` | NFS `192.168.178.62:/mnt/user/data` — downloads **and** library, RW |
| `/Music` | NFS `/mnt/user/Music`, RW — Lidarr's root folder and Jellyfin's music library |
| `/mnt/library` | NFS `/mnt/user/data` again, read-only, with FS-Cache — what Plex and Jellyfin play |
| `/media` | local folder of links: `/media/<folder>` → `/mnt/library/media/<folder>`, and `/media/Music` → `/Music` |
| `/srv/nixflix`, `/var/lib/qBittorrent` | local service state |

Library files are owned by **`unraid` uid 99 / `users` gid 100** to match Unraid's
share ownership.

- **Each NFS mount is the root of an export, and nothing is mounted below
  another NFS mount.** Unraid user shares hand out synthetic inode numbers, and
  Unraid gives the `media` folder a new one every few minutes. The kernel then
  logs `NFS: server 192.168.178.62 error: fileid changed`. A lookup by name
  recovers from that, but a mount does not:
  - A mount whose root is that folder stays `Stale file handle`. Until
    2026-10-26, `/media` was a mount of `data/media`, and Plex and Jellyfin lost it
    every few minutes.
  - The kernel detaches each mount below that folder. The old nested mounts
    `/data/media/Music` and `/media/Music` disappeared this way, and so did
    per-folder `ReadWritePaths` (see below).
  - A bind of a folder in `/data` keeps the dead handle when `/data` is mounted
    again (Plex, 2026-07-31).

  `fuse_remember` (**Settings → NFS** on Unraid) is `-1` since 2026-10-26 and did
  not stop it. Unraid gives that value to `shfs` only when the array starts.
- **`/media` is a folder of links**, declared in `storage.nix` from the folder list
  in `nixflix/common.nix`. For a new library folder, add it to that list, or Plex
  and Jellyfin do not see it under `/media`.
- `NAMESPACE` / `Stale file handle` → **`just mini media-restart`**. It stops the
  consumers, mounts the `storage.nix` topology again, and starts again what it
  stopped. An array restart on Unraid gives new inode numbers to everything, so
  run it after one.
- **Hardlinks require one `ReadWritePaths=/data` entry** — not per-subdir binds.
  Applies to the Arr services, qBittorrent, Bazarr and Unpackerr
  (`ProtectSystem=strict`).
  Symptoms of getting it wrong: `EXDEV`, "Read-only file system", or
  `file_open … Read-only file system` while the host mount is plainly RW (ADR-0006).
  A per-folder entry also loses its write access when Unraid changes the inode
  number of a parent folder (see above). On 2026-10-26 this made Bazarr read-only.
- Cleanup chain: qBittorrent `GlobalMaxRatio = 0` + `ShareLimitAction = Stop` stops
  seeding immediately; Arr `removeCompletedDownloads` removes the *client job* while
  library files survive via the hardlink.
- **Jellyfin trickplay is off on purpose** — NFS + full-library ffmpeg was
  multi-hour and multi-GB.
- `nixflix-setup-remote-dirs.service` must create the torrent/usenet/media subdirs
  on NFS before the stack starts.

### qBittorrent & VPN

- sops holds the **plaintext** WebUI password (`mini/media/qbittorrent/password`) —
  nixflix needs it for Arr→client auth; a root `ExecStartPre` derives
  `WebUI\Password_PBKDF2` into the conf so the flake never stores a hash.
- Search stays **inside** the VPN netns (ADR-0005). `nova3/engines` plugins are
  installed manually via the WebUI. A thin non-setuid wrapper points
  `pythonExecutablePath` at a `python3.withPackages` and strips qBittorrent's `-I`
  so `PYTHONPATH`/nova3 helpers work.
- **Sukebei torrents** get the category `jav` (folder `/data/torrents/jav`) and the
  tag `sukebei`. qBittorrent runs `qbittorrent-tag-sukebei` for each new torrent
  (`AutoRun.OnTorrentAdded`). The script acts only on torrents without a category
  (search or WebUI adds) that use a sukebei tracker. It logs to the journal under
  `qbittorrent-tag-sukebei`. The folder is under `/data/torrents`, so it stays on
  the SSD. The script calls the WebUI on the namespace address: the WebUI does not
  listen on loopback.
- **Port forwarding** (`port-forward.nix`). The namespace drops all inbound traffic
  on `wg0`. Every 45 s, `qbittorrent-port-forward` asks Proton's gateway
  (`10.2.0.1`) for a port over NAT-PMP. When the port changes, the unit opens it
  on `wg0` and makes it the qBittorrent listen port. qBittorrent's own UPnP /
  NAT-PMP is off (`Network.PortForwardingEnabled`), as Proton's guide says. This
  works only with a WireGuard configuration for a P2P server with
  "NAT-PMP (Port Forwarding)" on, and Moderate NAT off.
  With another configuration, `journalctl -u qbittorrent-port-forward` shows
  "no port from 10.2.0.1".
- **Search returns empty but the daemon is up** → check the WireGuard handshake age
  (`just mini vpn-status`). A dead peer makes indexer HTTPS time out.
- Use **`just mini vpn-restart`**, not a raw `systemctl restart wg`:
  SABnzbd usually hangs on stop with a dead tunnel (the recipe SIGKILLs it), and
  nixflix's `wg-up` gates on **ICMP ping** — Proton peers commonly drop ping even
  when UDP/51820 is fine, so a stock restart fails after teardown; the recipe
  installs a drop-in that probes UDP instead. Downloaders are `BindsTo=wg.service`.
- Handshake stuck at `0 B received` → that Proton server is down. Export a fresh
  profile into `mini/media/vpn/wireguard-conf` and `vpn-restart` again. Export it
  for a P2P server with "NAT-PMP (Port Forwarding)" on, or port forwarding stops.

Ops: `just mini media-status | arr-restart | media-restart | downloaders-restart |
stack-restart | vpn-status | vpn-restart`.

## 9. Matrix, Hermes, Caddy vhosts

Subdomains on the `jadee.fyi` Cloudflare zone, all → `mini-proxy`:
`home` (Homepage), `matrix`, `chat` (open-webui), `beszel`, `cinny`, `immich`, `hermes`, `atuin`, `ntfy`, `grafana`, plus the
media set (`sonarr`, `radarr`, `lidarr`, `prowlarr`, `sabnzbd`, `qbittorrent`, `seerr`,
`bazarr`, `jellyfin`, `plex`).

The first switch after a Caddy/Hermes bump builds two **uncached** packages locally
(plugin Caddy; Matrix-augmented Hermes).

### continuwuity accounts

There is **no CLI user creation**. Register against loopback `:6167` with
`/_matrix/client/v3/register` and an `m.login.registration_token` auth block.

> **The first account must use the *emergency* token printed in
> `journalctl -u continuwuity`** — it rotates on every restart. The configured
> `matrix/registration_token` is inert until one account exists, and that first user
> becomes server admin.

### Hermes

- **Matrix auth is an access token, not a password.** The password path re-logs-in on
  every restart, rotating the device identity key and breaking E2EE one-time keys +
  cross-signing. Live config: `MATRIX_ACCESS_TOKEN` + `MATRIX_RECOVERY_KEY` from
  sops, `MATRIX_DEVICE_ID=hermes-mini` pinned; `matrix/hermes_password` is
  break-glass only and is deliberately *not* in the env.
- **`.env` lives at `/var/lib/hermes/.hermes/.env`** (`$HERMES_HOME`, `hermes:hermes`,
  dir `0700`). Hermes reads it itself at process start — **not** via systemd
  `EnvironmentFile=` — so secrets are not hot-reloaded; the gateway must restart.
- **`.env` is fully regenerated from the sops template on every switch, not merged.**
  Any key written only by the dashboard/CLI is **wiped**. This ate
  `TELEGRAM_BOT_TOKEN` once (→ "No bot token configured"). **Rule: any connection
  secret added in the dashboard must also be added to sops + the `hermes.env`
  template.** Pre-switch `.env.bak-*` files in `$HERMES_HOME` are the recovery source.
- **Dashboard restart wedge (recurring hazard):** adding/editing a connection in the
  UI runs `hermes gateway restart`, which spawns a gateway **as a child of
  `hermes-dashboard.service`**, grabbing `gateway.lock`. `hermes-agent.service` then
  can never acquire it → "Gateway already running (PID …)" → permanent crash loop.
  Fix: stop both units, move `/var/lib/hermes/.hermes/gateway.lock` aside, start
  `hermes-agent` then `hermes-dashboard`. Prefer `systemctl restart hermes-agent`
  over the dashboard's restart action.
- **Dashboard shows a stale "Not configured"** after a secret is restored: it caches
  platform status at its own startup and the `hermes-agent-reload` path unit only
  restarts the *agent*. A plain `systemctl restart hermes-dashboard` is safe and does
  **not** trip the lock wedge (the wedge is the in-UI action only).
- Hermes runs **un-managed** (`HERMES_MANAGED=""`, `.managed` marker removed each
  switch) so the dashboard can persist config edits — `save_config()` no-ops in
  managed mode. Activation still deep-merges `services.hermes-agent.settings` into
  `config.yaml` on every switch, so **keys present in Nix `settings` revert dashboard
  edits**; everything else is dashboard-owned and persists. Keep `settings` minimal.
  `/var/lib/hermes/.hermes/config.yaml` is not tracked in git, and a symlink to a
  repo file is not an option — Hermes writes atomically (`os.replace`), replacing the
  symlink with a plain file on first save.
- Package is `pkgs.llm-agents.hermes-agent` (numtide, binary-cached) which ships all
  extras. **`extraDependencyGroups` / `extraPythonPackages` break eval** with it —
  the NousResearch module turns them into `cfg.package.override`, which only the
  hermes repo's own uv2nix build accepts.
- The dashboard is loopback-only behind Caddy, with no login (since 2026-10-26).
  The `tailnet-only` snippet in `services/caddy.nix` answers 403 to clients
  outside the tailnet, because Caddy also binds the LAN address. Every tailnet
  device controls hermes through it.
- The Tailscale auth key must be **reusable + non-ephemeral** or `mini-proxy` does
  not survive a restart.

### Atuin sync (`miniAtuinSync`)

Shell history for every host, at `https://atuin.jadee.fyi` → loopback `:8888`. The
server keeps history in an `atuin` database on the same postgres as Immich
(`services.atuin.database.createLocally`). Clients set `sync_address` in
`modules/profiles/minimal/shells/core/atuin.nix`.

History is end-to-end encrypted, so the server holds ciphertext only and needs no
sops secret. The encryption key lives on the clients. **Lose the key and the synced
history cannot be read**, so keep `atuin key` output in 1Password.

Registration is closed (`openRegistration = false`). To add an account: flip it to
true, switch, run `atuin register`, then flip it back and switch again.

### Homepage start page

`https://home.jadee.fyi` → loopback `:8082` (`services/homepage/`). One page with a
tile for each service on mini and Unraid. Each tile shows a status dot from a
loopback check. Most tiles also show live numbers from the service API.

- The full configuration is in Nix (`services.homepage-dashboard`). Homepage has no
  web editor. To add a tile, add it to a group in `homepage/default.nix`.
- The package comes from `pkgs-small` (nixos-unstable-small), because our
  nixos-unstable lock is behind. An expiry guard warns when the main lock has
  2.6.0, and then the pin goes back to `pkgs`.
- API keys come from sops through `LoadCredential`. Homepage reads each file where
  the configuration says `{{HOMEPAGE_FILE_<NAME>}}`. The browser never gets a key.
- Bazarr and Seerr keys are in sops too (`mini/media/bazarr/api-key`,
  `mini/media/seerr/api-key`). Bazarr gets its key from `services.bazarr.settings`.
  The Seerr preStart writes its key into `settings.json`.
- The page has no login. Access is limited to the tailnet and the LAN, as for the
  other vhosts. The Jellyfin widget has media control off, so a visitor cannot
  pause a stream.

Tiles without a widget, on purpose:

- **Lidarr:** the widget downloads the full artist list (over 7 MB) on every page
  load, only to count artists. The calendar gets albums from Lidarr's iCal feed.
  Homepage fetches the feed on the server and removes its URL, with the key, from
  what the browser gets.
- **Beszel:** Homepage's Beszel widget logs in only as a PocketBase superuser.
  Homepage does not get Beszel admin rights.

Look (`homepage/theme.nix`):

- The colors are the Birds of Paradise palette of mini's theme variant.
- The background shows the desktop wallpapers (`modules/profiles/theme/wallpapers`)
  in random order. The interval is Noctalia's
  `wallpaper.automation.interval_seconds`, so the page and the desktop change
  together. The build scales the images to 2560x1600, and Caddy serves them at
  `/wallpapers/`.

Widgets that need a manual step:

- **Unraid:** an API key named `homepage` in Unraid → Settings → Management
  Access → API, in `mini/homepage/unraid-api-key`. Homepage 2.6 documents the
  ADMIN role, but the widget only reads: a Viewer key gets all its fields.
- **Immich:** an API key of the admin account with the `server.statistics`
  permission, in `mini/homepage/immich-api-key`.
- **FRITZ!Box:** the widget uses UPnP status, with no login. If it shows an error,
  turn on Home Network → Network → Network Settings → "Transmit status information
  over UPnP".
- **ntfy:** nothing. The `homepage` ntfy user can only read the `system` topic.

## 10. Agent session archive (`miniAgentSessions`)

The plan and its decisions are in [session-management-plan.md](../agents/session-management-plan.md). The code is `services/agent-sessions.nix` (mini), `modules/profiles/devenv/agents/session-push.nix` (every Linux host), and `data/agents/session-sources.nix` (the folders per agent).

| Part | Facts |
|---|---|
| Archive | `/srv/agent-sessions/<host>/<agent>/`, in each agent's own layout. The top folder is `root:agent-sessions 2750`. `agent-push` owns each host folder. |
| Push | User timer `agent-session-push` on every Linux host, mini included, every 15 minutes. rsync over SSH to `mini.quokka-qilin.ts.net:2222` as `agent-push`. SQLite stores go as `.backup` snapshots without WAL mode. |
| Receiver | OpenSSH on port 2222, open only on `tailscale0`. Port 22 on the tailnet is Tailscale SSH, which ignores forced commands. Each host key runs `rrsync -wo -no-del /srv/agent-sessions/<host>` only. |
| hermes | Timer `agent-sessions-hermes`, every 15 minutes, as user `hermes`: `state.db` → `/srv/agent-sessions/mini-hermes/hermes/`. |
| Index | `agentsview.service`, user `agentsview` (group `agent-sessions`), `127.0.0.1:8089`, state in `/var/lib/agentsview`. |
| Web UI | `https://sessions.jadee.fyi`, tailnet clients only (Caddy snippet `tailnet-only`), no login. |
| Backup | `restic-backups-agent-sessions`, 03:45 daily, to Unraid `backup/agent-sessions`. Prune keeps 14 daily, 8 weekly, 24 monthly. The password is `mini/backup/agent-sessions-restic-password`; a copy is in Proton Pass. |

### Add a host to the push

1. Switch the host once. The switch makes `~/.ssh/agent_push_ed25519`.
2. Put the public key into `hosts/<host>/host.nix` as `agentPushKey`.
3. Deploy mini. Then switch the host again. The timer starts.

### Checks

- On a host: `systemctl --user status agent-session-push` and `journalctl --user -u agent-session-push`.
- On mini: `sudo du -sh /srv/agent-sessions/*` and `journalctl -u agentsview`.
- Session counts on mini: `curl -s -H 'Host: sessions.jadee.fyi' http://127.0.0.1:8089/api/v1/stats`.
- Backup: `sudo restic-agent-sessions snapshots`. Restore: `sudo restic-agent-sessions restore latest --target / --include /srv/agent-sessions`.

### Failure modes

- **systemd-tmpfiles: "unsafe path transition"**. A folder of root sits under a folder of an unprivileged user. Keep `/srv/agent-sessions` owned by root.
- **Push fails off the LAN, works at home**. The tailnet ACL blocks port 2222. Test with `nc -vz mini.quokka-qilin.ts.net 2222`.
- **A new SQLite source stays empty in agentsview**. agentsview opens sources read-only and cannot read WAL mode that way. Send a `.backup` snapshot and set `PRAGMA journal_mode=DELETE`.
- **An edit to `/var/lib/agentsview/config.toml` disappears**. The unit writes that file from the Nix template at each start. It keeps only the generated `cursor_secret` and `auth_token` lines. Change the template in `services/agent-sessions.nix`.
- **A work session reached the archive** (D10, manual). Remove it in three places: the raw files, the agentsview database, and the restic snapshots.

## 11. Known gaps / deferred

- **Nightly cachix cache-warm pipeline** — code exists at
  `hosts/mini/flake-cache-warm.nix` but the import is **commented out** in
  `hosts/mini/default.nix`. To bring online: `cachix create jadee-flake` (public
  read) → paste the public key over the TODO in `modules/shared/environment.nix` →
  push-scoped token into sops `cachix/auth-token` → GitHub deploy key (write) into
  `mini/git/deploy-key` → uncomment → `just switch` → `systemctl start
  flake-cache-warm.service`. Design (mass `nix flake update`, build the three
  closures, bisect per-input on failure and revert only the offending inputs, push
  the maximal working lockfile) lives in the module header.
- **Power tuning** — stock. Candidates: `powersave` governor, `thermald`, ASPM in
  BIOS, `logind.lidSwitch = "ignore"`. No `tlp` (laptop-oriented, conflicts with
  thermald). Wake-on-LAN pointless (always on).
- **Backups beyond Immich, the media state and the agent sessions** — Matrix,
  Hermes and the atuin database have no backup.
- **AMT-over-VPN** — needs a Tailscale subnet router on another always-on host.
- Verify Stylix/DMS/Niri stay inert with `desktop.enable = false` during a
  `just build-dry`; gate their imports on headless if any leak.

## 12. Rebuilding from scratch

Full procedure lives in git history (`docs/hosts/mini-install.md` before this
consolidation). The parts that are not obvious:

1. **MEBx (`Ctrl+P` at POST, physical access once):** change the `admin` password,
   DHCP + router reservation, enable SOL/IDER/KVM, **user consent None** (required
   for unattended headless access — accepted tradeoff), activate in **CCM**. Mirror
   the password to sops afterwards. Verify: `curl -k https://<amt-ip>:16993/` and
   `nix shell nixpkgs#amtterm -c amtterm <amt-ip>`.
2. **Installer wifi:** ethernet may not be routed yet. Disable NM scan MAC
   randomization first (`[device] wifi.scan-rand-mac-address=no` in
   `/etc/NetworkManager/conf.d/`) — some APs choke on it. If it sticks at
   "connecting (configuring)", delete the transient profile and re-add with
   `802-11-wireless.cloned-mac-address permanent`, `ipv4.method auto`,
   `ipv6.method disabled`.
3. **disko destroys both NVMes** — re-check `/dev/disk/by-id/nvme-…` for the 256 GB
   *and* the 2 TB disk before running it.
4. **`nixos-install --max-jobs 1 --cores 4`** — it uses the *installer's* daemon, so
   mini's `buildCores` does not apply, and 24 GB will thrash otherwise.
5. **Bootstrap mode is the chicken-and-egg fix and has been removed from
   `host.nix`.** sops-nix cannot decrypt before mini's age host key exists, so
   `users.users.jadee.hashedPasswordFile` cannot be declared on first install.
   Re-introduce a `miniBootstrap` toggle that (a) uses `initialPassword` and (b)
   skips `./services/llm`, then flip it off only after the sops checklist in §4 is
   complete. `--no-root-password` is correct — root stays locked, jadee has
   NOPASSWD wheel.
6. **Password SSH is disabled from first boot** — your key must already be in
   `data/users/users.nix` → `jadee.sshKeys` and committed *before* `nixos-install`.
   Recovery is console or AMT KVM only.
7. The installer's `/tmp/flake` clone is gone after reboot — clone to
   `~/git/flake` and run `just _init mini` before any `just` recipe.
8. SecureBoot enrollment last (§2), after the host is reachable.

Smoke test: key-only SSH from desktop and over Tailscale, `sudo whoami` without a
prompt, `sbctl status`, `amtterm`, `https://<amt-ip>:16993`, then each service's
`just mini …-status`.
