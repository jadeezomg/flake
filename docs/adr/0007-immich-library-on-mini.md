# 0007 — Immich library on mini, Unraid as backup target

**Status:** accepted (2026-08-01)

Immich's photo/video library and its Postgres database live on mini's local 2 TB
application NVMe (`/srv/immich`, `/var/lib/postgresql`). Unraid stops hosting the
Immich container and becomes the *backup destination* instead, receiving an
encrypted restic repository over SFTP.

This deliberately inverts [ADR-0004](./0004-media-automation-on-mini-payloads-on-unraid.md),
which puts media payloads on Unraid and mounts them over NFS. That ADR remains
correct for the Plex/Jellyfin/\*arr stack; Immich is a different workload.

## Coupled decisions

**Immich's access pattern is not the media stack's.** Plex and Jellyfin stream
large files sequentially, which is what NFS is good at. Immich does per-asset
random reads and writes across hundreds of thousands of small files, plus
thumbnail and transcode generation, plus a Postgres cluster whose rows must stay
consistent with the filesystem. A stale or slow mount does not degrade Immich
gracefully — it produces "missing files" across the library.

**This host has already been burned by NFS under a service.** The long comment
in `hosts/mini/services/media/storage.nix` records the 2026-07-31 incident: a
bind mount of a subdirectory under the automounted NFS tree pinned the
superblock, `x-systemd.idle-timeout=600` expired it, and the resulting ESTALE
wedged the consumer's systemd namespace (`226/NAMESPACE`). Putting a database's
backing files behind that is not a risk worth taking.

**Capacity is not the constraint.** `/srv` is a dedicated 2 TB NVMe with 1.8 TB
free. Unraid does not currently export a photos share at all (only `Music`,
`data` and `Stuff`), so the NFS option was not even free — it would have meant a
new export plus a fourth mount unit carrying the hazard above.

**Backing up therefore becomes mandatory, not optional.** Because mini now holds
the only copy of irreplaceable data, `hosts/mini/services/immich-backup.nix` ships
in the same host toggle (`miniImmich`) as the service itself. There is no
separate "backup disabled" flag — that is the kind of switch that gets flipped
for one debugging session and never flipped back.

**The library was re-imported, not migrated.** The Unraid instance ran
pgvecto.rs (`vectors` 0.3.0), which nixpkgs no longer ships, on a schema
predating Immich's 1.132→1.136→2.x→3.x upgrade chain — so its dump is
unrestorable here twice over. At ~596 assets, re-uploading the originals and
letting mini rebuild thumbnails, faces and embeddings costs minutes, against
several risky container upgrades on Unraid to clear both blockers. We accepted
losing albums, face names and shared links. EXIF rides along inside the
originals, so dates, camera data and GPS survived and the timeline is correct.

## Rejected alternatives

1. **Library on Unraid NFS, Immich on mini** — consistent with ADR-0004 and
   keeps the bytes on parity-protected storage. Rejected for the access-pattern
   and ESTALE reasons above. Postgres would still have had to be local, so the
   DB and the files it indexes would live on different failure domains, which is
   worse than either extreme.
2. **Keep Immich on Unraid** — no migration work. Rejected: it stays a Docker
   container outside the flake, unmanaged and undeclared, and Unraid's CPU is
   much weaker than mini's 16 cores for face detection and CLIP embedding.
3. **rsync mirror to Unraid instead of restic** — human-browsable photos on the
   array. Rejected as *the* backup: a mirror replicates deletion, so an Immich
   regression, an errant phone delete, or malware propagates on the next run. It
   also offers no integrity verification and no history. `restic mount` gives a
   browsable view of any snapshot at zero extra cost on the array.
4. **borg instead of restic** — matches the intent recorded in
   `docs/nix/builders-cache-backups-plan.md` § 4. Rejected here because borg
   needs `borg serve` on the far end (a container to maintain on an appliance
   whose `/root` is tmpfs) or a repo on a filesystem it controls; borg upstream
   does not support repos on network filesystems. restic's sftp backend needs
   nothing on Unraid but the stock `sftp-server`. That plan concerns the
   opposite direction (clients → mini as a repo), where mini owns a real local
   filesystem, and can still be borg — the two decisions need not match.

## Out of scope / future work

- Making `/srv/immich` its own btrfs subvolume so the nightly job can snapshot an
  atomic, point-in-time-coherent source and close the DB-at-T0 / media-at-T0+Nh
  skew. Cheap to add in `hosts/mini/disko.nix` before the library lands, and it
  also buys instant local rollback.
- The rest of mini's service state (`/var/lib/hermes`,
  `/var/lib/matrix-continuwuity`, `/var/lib/beszel*`) is still unbacked. This ADR
  establishes the transport, secret layout and notifier; a second
  `services.restic.backups.mini-state` job against the same repository with a
  different tag is a small follow-up.
- Sharing the Arc Pro B50 with Immich for video transcoding. Off by default to
  avoid contention with Plex (QSV) and llama.cpp (Vulkan); opt-in instructions
  are in `hosts/mini/services/immich.nix`.
