---
name: theme-structure
description: Apply this flake's cross-application theme and palette structure. Use when changing colors, adding app themes, wiring Stylix targets, or synchronizing generated themes across Nix, shell, Python, and GUI apps.
---

# Theme Structure

## Scope

Use this for theme palette changes and app-specific theme generation across the flake.

## Palette ownership

- `lib/theme-palette.nix` is the canonical color palette.
- `dotfilesLib.palette` is the module-facing access path for Nix code.
- `scripts/src/flake_scripts/lib/palette.py` mirrors the Nix palette for Python/Rich scripts; update both together.
- Do not hardcode palette hex values in app modules when `dotfilesLib.palette` can be used.

## App theme ownership

- App-specific theme generators belong with the app module.
  - Example: Typora theme code belongs under `modules/profiles/apps/notes/typora/` or the owning Typora module folder.
- Shared palette data belongs in `lib/`, not inside an app folder.
- Generated config installed through Home Manager should be declared by the owning app module.
- Mutable live configs use the live-symlink convention only when app edits should take effect without a switch.

## Cross-cutting policy

- Theme palette is shared data: expose it through `dotfilesLib.palette`.
- Stylix target settings belong with the feature/profile that owns the app integration.
- Shell/terminal theme helpers belong in their shell/theme profile.
- Browser/editor/app theme files belong with their app profile unless they are reusable shared data.

## Change rules

- Prefer semantic palette names (`bg-primary`, `accent-yellow`, `ansi-blue`) over one-off hex values.
- If adding a derived theme, keep the source style/layout near the app and substitute palette colors at generation time.
- If changing base palette values, audit all mirrors and generated consumers.
- Do not introduce a second palette source for one app.

## Checks

After theme changes:

1. Run `just fmt` for Nix/script changes.
2. If Python palette mirror changed, run the relevant script type checks via `just fmt`.
3. Eval or build the Home Manager activation output that installs generated theme files.
4. Read the generated theme/config file and verify palette values were substituted from `lib/theme-palette.nix`.
5. For live-symlinked desktop configs, run `flake symlink-check` / `just symlink-check` as appropriate.
