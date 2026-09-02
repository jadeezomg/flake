---
name: xdg-default-apps
description: Manage default desktop applications and MIME associations in jadee's dotfiles flake. Use when changing file type defaults, xdg.mimeApps, .desktop handlers, Nautilus/Yazi open-with behavior, or when an app unexpectedly opens a file type.
---

# XDG Default Apps

## Source of truth

- Linux MIME defaults live in `modules/profiles/desktop/mime.nix`. It is a NixOS module, gated on `dotfiles.profiles.desktop.enable`, that pushes `xdg.mimeApps` through `home-manager.sharedModules`. Headless hosts (`mini`) get no MIME table.
- Handler ids are one option, `dotfiles.desktop.mimeHandlers.{editor,browser,markdown,image,pdf,video,audio,fileManager,archive}`. Each is a desktop id without `.desktop`, or `null`. `mime.nix` declares the option and sets the baseline with `lib.mkDefault`. The table maps MIME types to `"${h.<role>}.desktop"`.
- An app profile claims a role with `lib.mkOverride 900`. That beats the baseline and still loses to a plain host assignment. Today only `apps/notes/typora/default.nix` does this, for `markdown`. Darwin has no `dotfiles.desktop` option, so that assignment sits inside `lib.optionalAttrs (!isDarwin)`.
- Yazi open-with rules live in `modules/profiles/essentials/utils/yazi/default.nix`. Yazi reads `osConfig.dotfiles.desktop.mimeHandlers.markdown` and maps the id to a command (`markdownOpeners`). Unknown ids run through `gtk-launch <id>`.
- Hand-written desktop entries live with the owning profile. The only one today is `pear-desktop` in `modules/profiles/apps/media.nix`. It has no MIME association.
- Darwin has no managed default apps. `modules/profiles/minimal/darwin/default.nix` only enables `xdg`. This is deliberate. Do not add macOS handler config there.

## Current handlers

GNOME apps come from `services.desktopManager.gnome.enable = true` in `modules/profiles/desktop/default.nix`. No profile installs them as packages.

- `org.gnome.Nautilus` (folders), `org.gnome.FileRoller` (archives). Both are also explicit packages in `modules/profiles/apps/files/default.nix`.
- `org.gnome.Loupe` (images), `org.gnome.Papers` (PDF), `org.gnome.Showtime` (video), `org.gnome.Music` (audio). GNOME session only.

Non-GNOME handlers, each with an explicit package:

- `dev.zed.Zed` (editor): `zed-editor` in `modules/profiles/devgui/ides/default.nix`. Owns text, code, config, and data types.
- `typora` (markdown): `pkgs.typora` in `modules/profiles/apps/notes/typora/default.nix`. The same file sets `mimeHandlers.markdown`. The `mime.nix` baseline for markdown is the editor.
- `zen-twilight` (browser, mailto): the `twilight` home module in `modules/profiles/apps/browsers/zen/default.nix`.

Intentionally unset: `application/octet-stream`, `x-scheme-handler/terminal`, and editor scheme handlers. Generic binaries and terminal URIs must not open in an editor.

## Coupled places

- `zen-twilight` is also the app-id in `modules/profiles/desktop/niri/outputs-desktop.kdl` and `keybinds-default.kdl`. A Zen channel change renames the `.desktop` id. Update all of them together.
- Yazi markdown rules follow `mimeHandlers.markdown`. Change the option, not the yazi file. Add a `markdownOpeners` entry in the yazi file only when a new markdown app needs a direct binary instead of `gtk-launch`.
- Yazi rules sit inside `lib.optionalAttrs hasMarkdownOpener`, which needs Linux, `apps.notes.enable`, and a non-null markdown handler. When `apps.notes` is off, the opener and the markdown rules vanish.
- Yazi `opener.open` is overridden, not extended. It holds `xdg-open` and "Show in Nautilus". Any new entry must be added to that list, or it drops the existing ones.

## Workflow

1. Verify the application exists in nixpkgs with `mcp-nixos`.
2. Read the package's `share/applications/*.desktop` file to get the desktop id.
3. Add or update the role in `dotfiles.desktop.mimeHandlers` in `modules/profiles/desktop/mime.nix`. A new role needs an `mkOption` entry and a `lib.mkDefault` baseline.
4. Add MIME mappings in `xdg.mimeApps.defaultApplications` in the same file.
5. Make sure the application is installed: a GNOME app needs the desktop profile, other apps need `environment.systemPackages` in their feature profile.
6. Add a Yazi rule only when the TUI needs its own open-with entry.
7. Use `lib.mkOverride 900` when an app profile owns a role. Use `lib.mkForce` only for a narrow, intentional override. No MIME `mkForce` exists today. Keep it that way unless the default is truly profile-specific.

## Conventions

- Store ids without `.desktop` in the option, for example `archive = lib.mkDefault "org.gnome.FileRoller"`.
- Map with `"application/zip" = [ "${h.archive}.desktop" ];`.
- Prefer GNOME-native handlers for GNOME file types.
- Feature profiles install tools. They do not own global MIME policy.

## Verification

Never build or switch yourself (see `AGENTS.md`).

1. Run `flake fmt`.
2. Run `git add` on changed `.nix` files. Flakes only see tracked files.
3. Eval the result. Quote attribute names that contain `/`:
   `nix eval --json '.#nixosConfigurations.desktop.config.home-manager.users.jadee.xdg.mimeApps.defaultApplications."text/markdown"'`
   Use `framework` in place of `desktop` when needed. `mini` must return `{}`.
   Check one role with `nix eval --json .#nixosConfigurations.desktop.config.dotfiles.desktop.mimeHandlers.markdown`.
4. Ask the user to switch and test with `xdg-mime query default <type>`.
5. For Yazi changes, ask the user to check `~/.config/yazi/yazi.toml` and run `yazi --debug`.
