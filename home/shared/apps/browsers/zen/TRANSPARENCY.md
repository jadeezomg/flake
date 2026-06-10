# Zen styling

Zen now relies on Stylix's native `zen-browser` target, including the opacity support added in Stylix PR #2332.

Removed from this repo:
- local `userChrome.css` / `userContent.css` transparency overrides
- local opacity plumbing in `home/shared/apps/browsers/zen/default.nix`
- forced transparent workspace themes in synced `spaces.nix`

Current wiring:
- `home/shared/assets/theme/stylix.nix` sets `stylix.targets.zen-browser.profileNames = ["default"]`
- `home/shared/apps/browsers/zen/default.nix` declares the managed Zen mod UUIDs; the upstream `zen-browser` Home Manager module installs mods and regenerates `zen-themes.css`
- Linux keeps `"zen.widget.linux.transparency" = true` in `profiles/default/default.nix`; Stylix does not set browser runtime prefs
- the Transparent Zen mod prefs in `settings.nix` remain intentional runtime settings
- workspace sync now writes only workspace metadata, not theme overrides

If transparency issues return, check upstream Zen, Stylix, and the Transparent Zen mod behavior first before reintroducing local CSS workarounds.
