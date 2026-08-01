# Mini — Immich

Self-hosted photo/video library, migrated off the Unraid Docker container.
Active when **`miniImmich = true`** in `hosts/mini/host.nix`.

| Policy | ADR |
|---|---|
| Library on mini's local NVMe; Unraid is the backup target | [0007](../adr/0007-immich-library-on-mini.md) |

## Layout

```
hosts/mini/host.nix              miniImmich = true
└── hosts/mini/default.nix       imports both modules under that one toggle
    ├── services/immich.nix          immich-server, immich-machine-learning,
    │                                postgresql (first on this host), redis
    └── services/immich-backup.nix   restic → Unraid, + maintenance + watchdog
```

## Storage model

| Path | Source | Role |
|---|---|---|
| `/srv/immich` | local 2 TB app NVMe (btrfs) | `IMMICH_MEDIA_LOCATION`; `upload/ library/ thumbs/ encoded-video/ profile/ backups/`; `0700 immich:immich` |
| `/srv/immich/backups` | same | nightly `pg_dump`, 3 kept locally — the handoff point for the restic job |
| `/var/lib/postgresql/17` | 256 GB system SSD (btrfs) | the host's only postgres cluster |
| `/var/cache/immich` | system SSD | ML model cache (`CacheDirectory`), re-downloadable |
| `/run/postgresql`, `/run/redis-immich/redis.sock` | tmpfs | unix sockets; no TCP, no password |

## Public URLs

| Host | Backend |
|---|---|
| `immich.jadee.fyi` | `127.0.0.1:2283` |

Machine learning listens on `127.0.0.1:3003` and is not proxied.

## Secrets

Canonical paths: `secrets/SCHEMA.md` § mini backup.

**Immich itself needs no secret** — postgres and redis are unix sockets, and all
application config lives in the database. Only the backup job has credentials
(`mini/backup/restic-password`, `mini/backup/unraid-ssh-key`,
`mini/backup/matrix-notify`).

## Settings: why `settings = null`

`services.immich.settings` is left `null` deliberately. Setting it to an attrset
flips Immich into `IMMICH_CONFIG_FILE` mode, which greys out the entire admin
settings page in the web UI. Storage template, job concurrency, transcoding,
backup schedule and external domain all live in the database and are edited
there — locking that surface to buy declarative control of a handful of toggles
is a bad trade for a household photo app. The declarative path's one real
advantage is secret injection (`somevalue._secret`) for OAuth, which is unused
here.

## Migration: re-import, not database restore

The Unraid instance ran **pgvecto.rs** (`vectors` 0.3.0) with
`IMMICH_MEDIA_LOCATION=/photos` and ~596 assets. Its database cannot be
restored here, for two independent reasons:

1. **The vector extension is gone.** nixpkgs ships only VectorChord —
   `services.immich` says outright that "pgvecto.rs is no longer available".
   A dump containing `CREATE EXTENSION vectors` fails on restore.
2. **The schema predates the upgrade chain.** Immich requires being started on
   a version between 1.132 and 1.136 before moving to 1.137+, then again
   through 2.x, before reaching the 3.0.3 nixpkgs ships. Restores migrate
   forward only.

Clearing both would mean walking the Unraid container up through several
versions and swapping its Postgres image first. For ~600 assets that is not
worth the risk: re-importing the originals and letting mini rebuild
thumbnails, faces and CLIP embeddings takes minutes on 16 cores.

**What is lost:** albums, face *names* (faces are re-detected, only the labels
go), shared links, and per-user settings. **What is kept:** every original file
with its embedded EXIF, so dates, camera data and GPS survive intact — the
timeline rebuilds itself correctly.

### Phase 1 — deploy

```sh
flake fmt && git add -A && git commit && git push
just mini deploy
just mini dns-sync          # once, so immich.jadee.fyi resolves
just mini immich-status
```

Open `https://immich.jadee.fyi`, create the admin account, then mint an API key
under **Account Settings → API Keys**. Unlike a database restore, this path
*wants* the account to exist first.

### Phase 2 — copy the originals

`/photos` is not one of Unraid's NFS exports (only `Music`, `data`, `Stuff`),
so this goes over SSH. It needs mini's backup key already installed on Unraid —
the same one the restic job uses, see *One-time Unraid prerequisites* below.

Copy **only the originals**. `thumbs/` and `encoded-video/` are derived and
Immich regenerates them; copying them wastes time and they would be ignored
anyway, since nothing in the new database references them.

```sh
sudo mkdir -p /srv/immich-import
sudo rsync -aH --info=progress2 \
  root@192.168.178.62:/photos/library/ \
  root@192.168.178.62:/photos/upload/  \
  /srv/immich-import/

sudo find /srv/immich-import -type f | wc -l     # sanity: ≈596 plus any strays
```

Staging on `/srv` costs a second copy of the originals for the duration. At this
library size that is trivial against 1.8 TB free.

### Phase 3 — import

```sh
immich login https://immich.jadee.fyi <api-key>
immich upload --recursive --concurrency 8 /srv/immich-import
```

Uploads are **checksum-deduplicated server-side**, so the command is safe to
re-run and resumable — an interrupted run picks up where it left off and
already-present assets are reported as duplicates rather than re-uploaded. That
also makes the `library/` + `upload/` overlap harmless: anything present in both
is stored once.

Immich queues thumbnail generation, face detection and CLIP embedding as the
assets land. Watch it drain under **Administration → Jobs**.

### Phase 4 — verify, then clean up

```sh
# expect 596
sudo -u postgres psql -d immich -tAc 'select count(*) from asset'
```

Cross-check the timeline in the browser, confirm dates look right (they come
from EXIF, not from file mtimes), and let the job queues reach zero. Only then:

```sh
sudo rm -rf /srv/immich-import
```

### Phase 5 — keep the source

Leave the Unraid `immich` and `PostgreSQL_Immich` containers **stopped but not
deleted**, with their appdata intact, for at least a few weeks. Because there is
no database restore, that container is the *only* remaining record of your
albums and face names — if you decide you want them after all, it is the only
place to read them from.

While it is stopped, note that its Postgres was exposed on
`192.168.178.62:5433` with `postgres`/`postgres`. mini's cluster is a unix
socket with peer auth and no password, reachable only from the host.

## Verification

```sh
just mini immich-status
just mini immich-vectors    # vchord + vector present; clip/face indexes populated
just mini immich-users      # the admin account you created in Phase 1
sudo -u postgres psql -d immich -tAc 'select count(*) from asset'   # expect 596
```

In the browser, each item proves one part of the pipeline ran:

1. Timeline loads with thumbnails → thumbnail generation finished
2. Dates and locations look right → EXIF was read from the originals, which is
   what makes a re-import acceptable in place of a database restore
3. Open an original, play a video → `upload/` and `encoded-video/` resolve
4. Explore → People shows detected faces (**unnamed** — the labels did not come
   across; re-name the ones you care about)
5. **Natural-language search ("beach sunset")** — the single best end-to-end
   signal: it exercises CLIP embeddings through vchord's index under NixOS's
   `search_path`. If this works, the whole vector stack is healthy.
6. Admin → Jobs: every queue drained, and Smart Search / Face Detection for
   **missing only** report ~0 pending
7. Admin → Settings → General → set **External Domain** to
   `https://immich.jadee.fyi` so shared links generate correct URLs
8. Mobile app: point at `https://immich.jadee.fyi`, log in, confirm the timeline
   and set the backup target

If search returns nothing while the job queues are empty, the vector indexes are
the thing to look at:

```sh
sudo -u postgres psql -d immich \
  -c 'REINDEX INDEX CONCURRENTLY clip_index; REINDEX INDEX CONCURRENTLY face_index;'
```

Worth knowing: `postgresql-setup` only REINDEXes when an *already-installed*
vchord extension changes version, so it never fires on a fresh database.

## Backup

`hosts/mini/services/immich-backup.nix` — restic over SFTP to
`root@192.168.178.62:/mnt/user/backup/immich`.

| Unit | Schedule | Job |
|---|---|---|
| `restic-backups-immich` | nightly 03:15 | `pg_dump` (as `ExecStartPre`), then snapshot `/srv/immich` |
| `restic-backups-immich-maint` | first Sunday 04:30 | `forget --prune` (14d/8w/12m/3y) + `check --read-data-subset=5%` |
| `immich-backup-watchdog` | daily 09:00 | asks the *repository* whether a snapshot < 36 h old exists |

The dump runs as `backupPrepareCommand`, so a failed dump **aborts** the
snapshot: media is never stored without a matching database. The dump is gated on
`gzip -t` plus `pg_dump`'s completion marker, and published by atomic `mv` from a
`.part` file, so restic can never capture a truncated dump.

The watchdog is not redundant with `OnFailure=`: a green timer proves nothing if
the unit was masked, mini was powered off for a week, or the repo was replaced.

**Never add `/var/lib/postgresql` to the restic paths.** A filesystem copy of a
live `$PGDATA` is torn pages plus a mid-stream WAL, and it is version-locked to
the exact `vchord.so` in the Nix store at that instant. The dump is the backup.

### One-time Unraid prerequisites

Each step says which machine to run it on — they are not all the same box, and
running the Unraid-side ones *from* Unraid over `ssh root@192.168.178.62` just
loops back to itself and prompts for the root password.

1. **On mini**, generate the keypair **in tmpfs**, not on disk:

   ```sh
   sudo ssh-keygen -t ed25519 -N '' -C 'mini@immich-backup' -f /dev/shm/k
   sudo cat /dev/shm/k.pub    # → Unraid WebGUI → Users → root → SSH authorized keys
   sudo cat /dev/shm/k        # → sops, as mini/backup/unraid-ssh-key
   sudo shred -u /dev/shm/k /dev/shm/k.pub
   ```

   The private key's only permanent home is sops, which decrypts it to
   `/run/secrets/…` at activation — any copy left on a filesystem is a second,
   unmanaged copy of a secret.

   `/dev/shm` specifically, because on mini `/tmp` is **not** tmpfs
   (`boot.tmp.useTmpfs = false`, `cleanOnBoot = false`) — it is a plain
   directory on the btrfs root that survives reboots. And btrfs is
   copy-on-write, so `shred` there cannot reliably overwrite the original
   extent. `/dev/shm` is RAM, and mini's only swap is zram (also RAM), so
   nothing reaches disk. If a key ever does land on `/tmp`, do not try to
   scrub it — generate a replacement so the exposed one was never a credential.

   Note the missing `-f` is not optional either: bare `ssh-keygen` as root
   writes `/root/.ssh/id_ed25519`, which is both persistent and liable to
   clobber an existing login key.

   Paste the **public** half into the Unraid WebGUI (required: `/root` is tmpfs
   *on Unraid*, so a hand-appended `authorized_keys` entry does not survive a
   reboot there).
2. **Unraid WebGUI:** Shares → Add Share `backup`; cache **No**, SMB **No**,
   NFS **No**. Not exporting it is the point — the only access path is the key.
3. **In a shell on Unraid:** `mkdir -p /mnt/user/backup/immich`
4. Settings → Disk Settings → `md_write_method` = **reconstruct write**. Parity
   read/modify/write caps the initial seed at ~40–80 MB/s; reconstruct write
   gives ~100–130 MB/s.

### Sizing

Photos are incompressible and do not dedup, so the repo starts at ≈1× the source
and grows by deltas. Budget **2×** the source size on Unraid, then measure with
`restic-immich stats --mode raw-data`. Derived data (`thumbs/`, `encoded-video/`)
is included on purpose: excluding it saves maybe 20–30% but leaves a bare-metal
restore unbrowsable until a multi-hour thumbnail job and a multi-day transcode
queue finish. The spike to watch for is an Immich upgrade that regenerates
thumbnails — that rewrites all derived data in one night.

### Restore

```sh
sudo restic-immich snapshots --tag immich
sudo systemctl stop immich-server immich-machine-learning
sudo restic-immich restore latest --target / --include /srv/immich --sparse --verify
sudo chown -R immich:immich /srv/immich && sudo chmod 0700 /srv/immich
```

Then restore the database from `/srv/immich/backups/` using the Phase 7 CLI block
and start the units. If mini is gone entirely, nothing about the repo is
mini-specific — decrypt `mini/backup/restic-password` and
`mini/backup/unraid-ssh-key` from sops on any host holding an age key and point
any restic at `sftp:root@192.168.178.62:/mnt/user/backup/immich`.

### Drill

An unverified backup is a rumour. Run `just mini immich-backup-drill` within a
week of the seed and quarterly after: it checks the repo, verifies the newest DB
dump is complete, and byte-compares 20 random originals straight out of the
repository against the live tree.

## Deploy / ops

```sh
flake fmt                       # after any .nix edit
git add -A                      # flakes only see tracked files
just mini deploy
just mini dns-sync              # once, after the vhost first appears
```

| Recipe | Purpose |
|---|---|
| `just mini immich-status` | server, ML, postgres, redis |
| `just mini immich-logs` | follow both Immich units |
| `just mini immich-restart` | bounce server + ML |
| `just mini immich-du` | media usage + database size |
| `just mini immich-users` | list accounts (post-restore check) |
| `just mini immich-vectors` | extension + vector index health |
| `just mini immich-media-location` | interactive `change-media-location` |
| `just mini immich-backup-status` | timers, last result, newest snapshot, repo size |
| `just mini immich-backup-now` | run the backup now and follow it |
| `just mini immich-backup-snapshots` | list snapshots |
| `just mini immich-backup-check` | run prune + integrity check now |
| `just mini immich-backup-drill` | restore drill |
| `just mini immich-backup-mount` | browse any snapshot as a filesystem |
| `just mini immich-backup-unlock` | clear a stale restic lock |

## Gotchas

- **Postgres major is pinned** to 17 in `services/immich.nix`. `stateVersion`
  selects it today; the on-disk cluster format is permanent, so a future bump is
  a manual offline `pg_upgrade`, not a rebuild. Every future service that wants
  postgres inherits this cluster and this pin.
- **`nix flake update` can move Immich to a new major**, which runs irreversible
  migrations on next start. Read the release notes and take a manual dump first.
- **GPU is off by default.** Enabling `accelerationDevices` buys video
  transcoding only — nixpkgs has no OpenVINO `immich-machine-learning`, so
  CLIP/face inference stays on CPU either way. The module does *not* add the
  `render`/`video` groups for you.
- **The `immich-cli` version must track the server.** Both come from the same
  nixpkgs so they move together; do not install the CLI from npm, where it will
  drift out of API compatibility.
- **This instance's history starts at the import.** There was no database
  restore, so albums, face names and shared links from the Unraid era exist
  nowhere on mini. The stopped Unraid containers are the only copy — see
  *Migration* Phase 5 before deleting them.
