# Zen transparency (NixOS + Stylix + Niri)

Linux compositor transparency for Zen: see-through window shell with ~90% tinted chrome (sidebar, toolbar, urlbar). Stylix colors stay on text, tabs, and accents.

## What actually fixes it

| Piece | Where | Why |
|-------|--------|-----|
| **`zen.themes.disable-all = true`** | `settings.nix` | **Main fix.** Workspace gradient themes apply via JS after session restore and paint an opaque layer over the shell (brief flash, then solid). |
| **`zen.widget.linux.transparency = true`** | `profiles/default/default.nix` | Required on Linux for a transparent GTK window background. |
| **Custom `userChrome` / `userContent`** | `default.nix` + `chrome/*.css` | Stylix colors + transparent shell + `color-mix` chrome at `stylix.opacity.applications`. |
| **`mod.sameerasw.zen_bg_color_enabled = false`** | `settings.nix` | Transparent Zen mod otherwise sets opaque `--zen-main-browser-background`. |
| **`stylix.targets.zen-browser.enableCss = false`** | `assets/theme/stylix.nix` | Avoids a second Stylix `userChrome` that fights the merged file in `default.nix`. |

`stylix.opacity.applications` does **not** apply to Zen automatically (unlike Kitty). It is wired through `chrome/userChrome.css` (`90%` → Nix-substituted percent) and `--zen-chrome-*` vars in `default.nix`.

## CSS load order

1. `userChrome.css` — Stylix block, then `:root` vars, then opacity layer (`!important` wins within this file).
2. `zen-themes.css` — Zen mods (loads **after** `userChrome`). HM activation appends a short Nix tail so the shell stays transparent.

## Do not use

- **Niri `opacity` on Zen windows** — fades the entire window (UI + web content). Use blur only in `niri/window-rules.kdl`.
- **Stylix `enableCss = true` for zen-browser** while also deploying custom `userChrome` in `default.nix`.

## Files

| File | Role |
|------|------|
| `settings.nix` | Shared prefs (`zen.themes.disable-all`, mod transparency) |
| `default.nix` | Merges Stylix + `chrome/*.css`; regenerates `zen-themes.css` on activation |
| `chrome/userChrome.css` | Transparent shell + tinted chrome surfaces |
| `chrome/userContent.css` | Tinted `about:` pages |
| `profiles/default/spaces.nix` | Optional `theme.opacity = 0.0` per workspace (only if `// spaces` is enabled in profile) |

## Tuning

- Global chrome opacity: `stylix.opacity.applications` in `assets/theme/stylix.nix` (default `0.9`).
- Mod sidebar blur: `mod.sameerasw.zen_bg_blur` in `settings.nix`.

## Trade-off

`zen.themes.disable-all` turns off per-workspace gradient wallpapers. Re-enabling them without `disable-all` tends to bring back the post-startup opaque layer.

## After config changes

Quit Zen completely, then `nixos-rebuild switch` / `home-manager switch`. Restart Zen so `prefs.js` and `chrome/` update.

## Quick verify

```bash
grep zen.themes.disable-all ~/.config/zen/default/prefs.js    # true
grep zen.widget.linux ~/.config/zen/default/prefs.js           # true
tail -5 ~/.config/zen/default/chrome/zen-themes.css          # nix transparency tail
grep -c 'background-color: #' ~/.config/zen/default/chrome/userChrome.css  # Stylix lines OK; tail should use transparent / color-mix
```
