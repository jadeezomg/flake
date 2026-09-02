---
name: theme-structure
description: Apply this flake's cross-application theme and palette structure. Use when changing colors, fonts, or wallpapers, adding app themes, wiring Stylix targets, or synchronizing the hand-copied palette mirrors across Nix, shell, Python, and GUI apps.
---

# Theme Structure

## Scope

Use this skill for palette, font, wallpaper, Stylix, and app theme changes.

## Sources of truth in `lib/`

- `lib/theme-palette.nix` is the canonical Birds-of-Paradise palette. Nix code reads it as `dotfilesLib.palette`.
- `lib/theme-base16.nix` maps palette keys to base16 slots. Stylix consumes it as `dotfilesLib.themeBase16`. A new palette key does nothing for Stylix until you map it here.
- `lib/theme-fonts.nix` selects the fonts. `dotfilesLib.themeFonts { inherit pkgs; }` feeds `theme/stylix.nix` and `modules/profiles/fonts/default.nix`, so Stylix names only installed fonts.
- `lib/default.nix` exposes all three. Do not import them by relative path.

## Hand-copied palette mirrors

These files repeat the hex values by hand. A palette change must update all of them:

- `scripts/src/flake_scripts/lib/palette.py` (Rich styles for the Python scripts).
- `data/agents/omp/themes/birds-of-paradise.json` (OMP agent theme).
- `modules/profiles/desktop/dms/config/birds-of-paradise.json`.
- `modules/profiles/desktop/dms/config/themes/birds-of-paradise/theme.json`.
- `modules/profiles/desktop/niri/config.kdl` (focus ring `active-color` and `inactive-color`).

## Theme profile split (`modules/profiles/theme/`)

- `default.nix` pushes the HM modules through `home-manager.sharedModules`.
- `stylix.nix` is always pushed. It enables Stylix with `autoEnable = true`, the base16 scheme, the fonts, and the CLI targets. The headless host must keep working with only this file.
- `gui.nix` and `qt-kde.nix` are pushed only when `theme.gui` is enabled. `gui.nix` holds opacity, cursor, `stylix.image`, and GTK.
- `qt-kde.nix` generates `~/.config/kdeglobals` and a qt5ct/qt6ct color scheme from `dotfilesLib.palette`. The Stylix `kde` target is inert outside Plasma, so Kirigami apps and qt6ct get no palette without this file.

## Stylix ownership rule

- All `stylix.targets.*` settings live in `theme/stylix.nix` and `theme/gui.nix`. App modules do not set targets.
- With `autoEnable`, do not hand-write colors for an app that a Stylix target covers. Commit 59afbdc removed the hand-written nushell theme for this reason.
- App modules can read `config.stylix.*` (for example, `ghostty.nix` reads the font names).
- App modules can post-process Stylix output. `devgui/ides/zed/theme.nix` is the pattern: an activation script after `linkGeneration` copies `zed/themes/stylix.json` out of the store and patches it with `jq`.
- Two deliberate exceptions exist:
  - Starship: `essentials/shell-theme/starship.nix` sets `palette = lib.mkForce "birds-of-paradise"` and builds the palette from `dotfilesLib.palette`. `shell-theme/` holds only this file.
  - VSCode: `stylix.nix` disables the `vscode` target. `devgui/ides/vscode/default.nix` installs the marketplace `birds-of-paradise` extension instead. This is the one sanctioned second palette source for an app.

## Palette consumers that generate config

- `apps/notes/typora/theme.nix` renders CSS from `{ palette }`. The owning module writes it to `Typora/themes/birds-of-paradise.css`.
- `essentials/fastfetch.nix` colors the logo and section keys from `dotfilesLib.palette`.
- `theme/qt-kde.nix` (see above).
- Keep generator code next to the app module. Keep shared data in `lib/`.

## Wallpapers and images

- `theme/gui.nix` sets `stylix.image = ./wallpapers/wallpaper.jpg`.
- Assets live in `modules/profiles/theme/wallpapers` and `modules/profiles/theme/images`. `gui.nix` live-symlinks them to `~/Pictures/Wallpapers` and `~/Pictures/Images`.
- Noctalia keeps its own absolute wallpaper paths in `desktop/noctalia/config/settings.toml`. The GUI writes this file, so it drifts. Review the diff before you commit it.

## Theme delivery through live symlinks

The helper module `lib/home/live-xdg-symlinks.nix` is exposed as `config.lib.dotfiles` (`mkLiveSymlink`, `xdgConfigDirSymlinks`). Edits to a live-symlinked file apply without a switch.

- DMS: `desktop/dms/default.nix` links `~/.config/DankMaterialShell/*` from `dms/config` with `xdgConfigDirSymlinks`. The theme JSON files above travel this way.
- OMP: `devenv/agents/global-config.nix` links `~/.omp/agent/themes/birds-of-paradise.json` to the `data/agents` file.
- Noctalia: `desktop/noctalia/default.nix` links `~/.local/state/noctalia/settings.toml` with `mkLiveSymlink`. This file wins over the HM-generated `config.toml`.

## Noctalia Stylix merge contract

`programs.noctalia.settings` is built with `lib.mapAttrsRecursive (_: v: lib.mkDefault v)` over the parsed TOML. Stylix defines nested keys at normal priority, so per-leaf `mkDefault` lets Stylix win only the keys it sets. A `mkDefault` around the whole attrset is filtered away before type merging and drops most sections. Keep the per-leaf form.

## Change rules

- Use semantic palette names (`bg-primary`, `accent-yellow`, `ansi-blue`), not one-off hex values.
- If you add a color for Stylix, map it in `lib/theme-base16.nix`.
- If you change a hex value, update every mirror in the list above.
- If you add a font, change `lib/theme-fonts.nix` only. Both consumers follow it.
- Do not add a second palette source for one app. VSCode is the only exception.

## Checks

1. Run `just fmt` after Nix or Python edits.
2. Ask the user to build the affected Home Manager output. Do not run build or switch commands yourself.
3. Read the generated theme file and make sure that the hex values match `lib/theme-palette.nix`.
4. For live-symlinked desktop configs, run `just symlink-check`. For the strict DMS check, run `just symlink-check-dms`. The underlying command is `uv run --project scripts symlink-check {all|dms-settings|noctalia-settings}`.
