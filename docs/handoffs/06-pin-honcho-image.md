# Task 6 — Pin the honcho image to a digest

**State:** quick hardening task. `hosts/mini/services/honcho.nix` uses
`image = "ghcr.io/plastic-labs/honcho:latest"` (mutable tag) — there's a TODO in
the file to pin it.

## Steps
1. Get the digest currently running on mini:
   `ssh mini 'bash -lc "podman image inspect ghcr.io/plastic-labs/honcho:latest --format {{.Digest}}"'`
2. Set `image = "ghcr.io/plastic-labs/honcho@sha256:<digest>";` in `honcho.nix`.
3. (Optional, same idea) pin `docker.io/pgvector/pgvector:pg15` and `docker.io/redis:7-alpine` to digests too.
4. `flake fmt`, `git add`, `nix eval ".#nixosConfigurations.mini.config.system.build.toplevel.drvPath"`, commit/push, `just mini deploy`.

## Notes
- Pinning a digest means honcho upgrades become an explicit, reviewable bump (good for reproducibility). Bump by re-fetching `:latest`'s digest when you want a newer version.
- Not urgent; do it opportunistically (e.g. alongside Task 2).

## Suggested skills
- none specific.
