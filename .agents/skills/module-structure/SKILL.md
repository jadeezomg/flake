---
name: module-structure
description: Apply this flake's module/profile organization rules. Use when adding or reorganizing files under modules/profiles, splitting mixed app config, deciding between default.nix, app.nix, and app/default.nix, or moving Home Manager settings.
---

# Module Structure

## Scope

Use this skill for `modules/**`, mainly `modules/profiles/**`. For hosts, packages, lib, scripts, and docs, use `flake-structure`.

## Module tree

- `modules/shared/`: options that exist on both NixOS and darwin (environment, security, shells).
- `modules/nixos/`: Linux platform baseline (boot, gc, networking, sops, users, virtualization).
- `modules/darwin/`: darwin platform baseline. `nix.settings` is inert on darwin. Put daemon settings in `modules/darwin/nix.nix` through `determinateNix.customSettings`. Do not re-enable `nix.enable`.
- `modules/profiles/`: the `dotfiles.profiles.*` and `dotfiles.hardware.*` feature layer. Hosts import all three trees from `hosts/<name>/default.nix`.

## Special args

`parts/hosts.nix` passes these. Do not add climbing imports to get them.

- System modules (NixOS and darwin): `inputs`, `hostData`, `dotfilesLib`, `host`, `hostKey`, `user`, `isDarwin`, `pkgs-stable`, `pkgs-small`. NixOS also gets `system`. Darwin does not.
- HM modules: `inputs`, `hostData`, `dotfilesLib`, `host`, `hostKey`, `isDarwin`, `pkgs`, `pkgs-stable`, `pkgs-small`. HM does not get `user` or `system`. HM reads system profile flags through `osConfig`.
- `pkgs-small` is passed but no module uses it today.
- `hostKey` is `desktop`, `framework`, `caya`, or `mini`. `host` is the record from `hosts/hosts.nix`. `hostData` is the full registry.
- `dotfilesLib` is `lib/default.nix`. It exports `palette`, `themeBase16`, `themeFonts`, `shellEnvData`, `shellPaths`, `minimalPackages`, `nixCaches`, `sshDestinations`, `lanHosts`, `users`, `hostStatus`, `nonoProfiles`, `nixExperimentalFeatures`, `expiry`, `agentsDataDir`, `agentSkillsDir`, `agentDataFiles`, and `sopsFile`. Functions are unapplied. MCP registration lives in `modules/profiles/devenv/agents/apm.nix`, not in `dotfilesLib`.

## Options

- Declare every `dotfiles.profiles.*` and `dotfiles.hardware.*` option in `modules/profiles/default.nix`. Set them per host in `hosts/<name>/profiles.nix`.
- Use `enableOn` for default-on profiles (minimal, essentials, fonts, theme, desktop, integrations). Use `mkEnableOption` for opt-in profiles (apps, devenv, devgui, llm, gaming, work, server).
- Declare options unconditionally. Gate Linux-only leaves at import level with `lib.optionals (!isDarwin) [ ... ]`, as in `modules/profiles/default.nix` and `apps/default.nix`. Do not use `mkIf` for this. The option namespaces do not exist on darwin.
- Profiles say what a machine is for. `dotfiles.hardware` traits say what a machine is: `wireless.enable`, `gpu` (`nvidia`, `amd`, `intel`, `none`), `cpu.zen4.enable`, `cpu.x3d.enable`. The leaves live in `modules/profiles/hardware/`.
- `modules/profiles/default.nix` asserts that a `hostClass = "server"` host does not enable a GUI profile. When you add a GUI profile, add an assertion there.
- `devenv.languages` is `attrsOf submodule`. Each language is `modules/profiles/devenv/languages/<name>.nix` behind `lib.mkIf cfg.enable`. Add the name to the `langs` list in `languages/default.nix` and in `devenv/default.nix`.

## Profile shape

- A profile folder's `default.nix` is the index and the shared baseline.
- Keep package-only groups in the profile `default.nix`.
- When an app has config, give it its own named module. That module owns install and config.
- Do not split system and HM config to preserve a `home.nix`. Inject HM config with `home-manager.sharedModules` from the system module.
- Put pure data in a `data/` folder beside the module, for example `minimal/shells/core/data/aliases.nix`.

## File vs folder

Three patterns exist. Pick the smallest that fits.

- `app.nix`: one file holds install and config.
- `app/default.nix`: the app needs helpers or generated files beside it, for example `notes/typora/theme.nix` or `browsers/zen/settings.nix`.
- `app.nix` plus a sibling `app/` folder: the leaf is the entry point and pulls the folder in. Examples: `editors/helix.nix` imports `helix/`; `apps/media.nix` pushes `media/home.nix` through `sharedModules`; `desktop/niri-hm.nix` symlinks `niri/*.kdl`; `devgui/ides/zed/settings.nix` folds `settings/*.nix`.

`app/home.nix` is the HM half of a system leaf `app.nix`. That is the one sanctioned `home.nix`. Do not leave a generic `home.nix` without a system owner.

Keep helpers that belong to one app inside that app's folder. `desktop/dms-greeter-acl.nix` and `desktop/gdm-session.nix` sit loose beside `dms/` and `gdm/`. They are known exceptions. Do not move them.

## Imports and policy

- Never climb out of a feature folder with `../` imports. `just lint` rejects only `import ../../..` (three levels) under `modules/`. The policy covers every climb, not only the ones the lint finds.
- Pure shared data comes from `dotfilesLib`. HM helpers come from `config.lib.dotfiles`.
- A file that no `default.nix` imports is ignored.
- Cross-cutting policy lives with the policy domain, not with the app it names.
  - MIME defaults: `modules/profiles/minimal/linux/environment.nix`.
  - Yazi openers: `modules/profiles/essentials/utils/yazi/default.nix`.
  - Palette: `lib/theme-palette.nix` through `dotfilesLib.palette`.

## Live symlinks

For app config that stays writable by the app, expose an out-of-store HM symlink.

- Use `config.dotfiles.flakeRoot` for repo paths. Never hardcode `/home/...`.
- Helpers on `config.lib.dotfiles` (from `lib/home/live-xdg-symlinks.nix`): `mkLiveSymlink target`, `xdgConfigDirSymlinks { readDirPath, liveDirAbs, relPrefix, exclude }`, `xdgConfigDirSymlinksPred { readDirPath, liveDirAbs, relPrefix, predicate }`, and `liveFlakeRoot homeDirectory`.
- Use the bulk helpers for whole config folders. See `desktop/dms/default.nix` and `desktop/niri-hm.nix`.
- Do not use live symlinks for secrets, databases, logs, caches, or generated state.
- Test DMS and niri links with `just symlink-check`. Use `just symlink-check-dms` for the strict DMS settings check.

## Refactor rule

- Improve structure only in folders that you already touch.
- Do not start broad reorganizations unless the user asks.
- Move imports in one cutover. Leave no orphan helper or generic `home.nix`.

## Checks

1. Run `just fmt`.
2. Run `git add` on changed Nix files before Nix eval or build.
3. Eval the option or package that the move affects.
4. Ask the user to run the build for HM or system changes. Do not run it yourself.
