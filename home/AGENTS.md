# HOME

Home-manager configuration for all users.

## Where to Put Things

| What | Where |
|------|-------|
| User packages (cross-platform) | `home/shared/apps/` or `home/shared/development/` |
| User packages (Linux-only) | `home/nixos/` |
| User packages (macOS-only) | `home/darwin/` |
| macOS Homebrew casks/brews | `modules/profiles/work/darwin.nix` |
| Theme | `home/shared/assets/theme/` |
| Fonts | `modules/profiles/fonts/` |
| Desktop / Wayland config | `home/nixos/desktop/` |

## Desktop Stack (Linux)

Config lives in `home/nixos/desktop/`. `home/nixos/desktop/dms/default.nix` uses `mkOutOfStoreSymlink` — edits take effect without a switch:
- All DMS config files except `settings-*.json` are auto-symlinked
- `settings.json` → host-specific `settings-{framework,desktop}.json`
- `niri/host.kdl` → host-specific `outputs-{framework,desktop}.kdl`

After editing: `just symlink-check`, then `niri msg action load-config-file` and `makoctl reload`.

## Live Symlink Convention

For mutable app config that should live in git but remain writable by the app, store the file under the flake checkout and expose it with an out-of-store Home Manager symlink:
- Use `config.dotfiles.flakeRoot` for the repo path, never a hardcoded `/home/...` path.
- Use `mkLiveSymlink` from `lib/home/live-xdg-symlinks.nix` for both `home.file` and `xdg.configFile` entries. It sets `mkOutOfStoreSymlink` plus `force = true`.
- Put cross-platform user config in `home/shared/`; put Linux-only desktop config in `home/nixos/`.
- Do not use this for secrets, databases, logs, caches, or generated state. Keep those in the app's normal writable directory.

lanzaboote handles secure boot (`/var/lib/sbctl`); `systemd-boot` is force-disabled — don't touch `boot.loader.systemd-boot.enable`.

## Theme

**Birds of Paradise** (dark brown/warm palette). Defined in `home/shared/assets/theme/theme.nix`. Python mirror at `scripts/src/flake_scripts/lib/palette.py` — keep both in sync when updating colors.

Stylix enabled globally (`stylix.autoEnable = true`). VSCode, Firefox, and niri targets explicitly disabled. GTK gets custom CSS for 90% opacity.

## Gotchas

- **DMS settings not store-copied** — `settings.json` is a live symlink; run `just symlink-check-dms` to verify
- **Lanzaboote requires sbctl** — secure boot keys at `/var/lib/sbctl`; run `sbctl` before lanzaboote works on fresh install; never touch `boot.loader.systemd-boot.enable`
- **`backupFileExtension = "backup"` + `overwriteBackup = true`** — old `.backup` files accumulate; clean with `just backups-clean`
