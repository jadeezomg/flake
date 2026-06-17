---
name: module-structure
description: Apply this flake's module/profile organization rules. Use when adding or reorganizing files under modules/profiles, splitting mixed app config, deciding between default.nix, app.nix, and app/default.nix, or moving Home Manager settings.
---

# Module Structure

## Scope

Use this for `modules/**`, especially `modules/profiles/**`. For top-level hosts/packages/lib/scripts/docs, use `flake-structure`.

## Special args

System and HM modules can use: `pkgs`, `lib`, `config`, `inputs`, `hostKey`, `host`, `user`, `isDarwin`, `system`, `pkgs-small`, `pkgs-stable`, `dotfilesLib`.

Important ones:

- `hostKey`: `desktop`, `framework`, `caya`, or `mini`.
- `host`: full host record from `hosts/<hostKey>/host.nix`.
- `dotfilesLib`: cross-tree data/helpers such as `palette`, shell paths/env data, package lists, MCP servers, skills dir, and SOPS file.

## Profile shape

- All profile content lives under `modules/profiles/`.
- Profile toggles are declared in `modules/profiles/default.nix` and enabled per host in `hosts/<name>/profiles.nix`.
- A profile folder's `default.nix` is the index and shared baseline.
- Keep package-only groups in the profile `default.nix` when they have no meaningful config.
- When an app/service has configuration, give it its own named module.
- The app module owns both package install and configuration.
- Do not split system and Home Manager config just to preserve `home.nix`; this repo is mainly single-user, so colocate related settings and inject HM config with `home-manager.sharedModules` when needed.

## File vs folder

- Use `app.nix` when one file can hold the app's install plus config cleanly.
- Use `app/default.nix` when the app needs any helper or generated artifact beside it.
- Put app-owned helpers beside that app's `default.nix`, for example `typora/theme.nix` or `zen/settings.nix`.
- Avoid loose helper files in the parent profile folder when they belong to one app.

## Imports and policy

- Never climb trees with `../../` imports from modules; `just lint` rejects this.
- Pure shared data comes through `dotfilesLib`; HM helpers come through `config.lib.dotfiles`.
- Relative imports are for within a feature folder only.
- Conditional files need a `default.nix` import; files not imported are ignored.
- Cross-cutting policy lives with the policy domain, not the app it mentions.
  - MIME defaults: `modules/profiles/minimal/linux/environment.nix`.
  - Yazi openers: `modules/profiles/essentials/utils/yazi/default.nix`.
  - Theme palette: `lib/theme-palette.nix` via `dotfilesLib.palette`.

## Live symlinks

For mutable app config that should live in git but remain writable by the app, expose an out-of-store Home Manager symlink:

- Use `config.dotfiles.flakeRoot` for repo paths, never hardcoded `/home/...`.
- Use `mkLiveSymlink` from `config.lib.dotfiles` helpers.
- Do not use live symlinks for secrets, databases, logs, caches, or generated state.
- DMS/niri live configs should be verified with `flake symlink-check` / `just symlink-check`.

## Refactor rule

- Opportunistic, not sweeping: improve structure for folders you are already touching.
- Do not launch broad reorganizations unless the user asked for them.
- Clean cutover only: migrate imports and leave no orphan generic `home.nix`/helper file when config now has a clear owner.

## Checks

1. Run `just fmt`.
2. `git add` changed Nix files before Nix eval/build.
3. Eval the concrete option or package presence affected by the move.
4. Build the relevant HM activation package for HM changes.
5. Dry-run the affected system build when system modules/imports changed.
