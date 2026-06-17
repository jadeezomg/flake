---
name: xdg-default-apps
description: Manage default desktop applications and MIME associations in jadee's dotfiles flake. Use when changing file type defaults, xdg.mimeApps, .desktop handlers, Nautilus/Yazi open-with behavior, or when an app unexpectedly opens a file type.
---

# XDG Default Apps

## Source of truth

- Global Linux MIME defaults live in `modules/profiles/minimal/linux/environment.nix`.
- Feature profiles install applications; they should not own global MIME policy unless the default is intentionally profile-specific.
- Yazi open-with rules live in `modules/profiles/essentials/utils/yazi/default.nix`.
- App-specific desktop entries live with the owning profile's Home Manager module.

## Workflow

1. Verify the target application exists in nixpkgs with `mcp-nixos` before adding it.
2. Verify its desktop id by reading the package's `share/applications/*.desktop` file.
3. Add or update the app identifier in the `let` block of `modules/profiles/minimal/linux/environment.nix`.
4. Add MIME mappings to `xdg.mimeApps.defaultApplications` in that same file.
5. Install the application in the relevant feature profile's `environment.systemPackages`.
6. Use `lib.mkForce` only for narrow, intentional profile overrides.
7. Keep Yazi rules separate from XDG defaults; add Yazi openers only when the TUI needs an explicit open-with entry.

## Conventions

- Store app ids without `.desktop` in variables, for example `archiveManager = "org.gnome.FileRoller"`.
- Use `"application/zip" = ["${archiveManager}.desktop"];` style mappings.
- Prefer GNOME-native handlers for GNOME desktop file types: Nautilus for folders, File Roller for archives, Loupe for images, Showtime for videos.
- Do not set `application/octet-stream`; generic binaries should not open in an editor by default.

## Verification

After editing `.nix` files:

1. Run `just fmt`.
2. Run `git add` for changed Nix files before Nix eval/build.
3. Eval concrete associations, for example:
   - `nix eval --json '.#nixosConfigurations.framework.config.home-manager.users.jadee.xdg.mimeApps.defaultApplications.application/zip'`
   - `nix eval --json '.#nixosConfigurations.framework.config.home-manager.users.jadee.xdg.mimeApps.defaultApplications.text/markdown'`
4. Build the affected Home Manager activation package.
5. For Yazi changes, inspect generated `.config/yazi/yazi.toml` and run `yazi --debug` against it.
