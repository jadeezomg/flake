# MODULES

System-level NixOS/Darwin configuration.

## Special Args Available in All Modules

```nix
{ pkgs, lib, config, inputs, hostData, hostKey, host, user, isDarwin, system, pkgs-small, pkgs-stable }
```

- `hostKey` — `"desktop"`, `"framework"`, `"caya"`, or `"mini"` (use for host conditionals)
- `host` — full host record from `hosts/<hostKey>/host.nix` (includes `mainMonitor.*`, `buildCores`, `dmsSettingsFile`, `niriOutputsFile`, …)
- `isDarwin` — `true` on macOS
- `pkgs-small` — nixpkgs-unstable-small (pinned, no local overlays)
- `pkgs-stable` — nixpkgs 25.11 (pinned, no local overlays)
## Common Patterns

```nix
lib.mkIf (hostKey == "desktop") { ... }        # host-conditional
lib.optionals (!isDarwin) [ pkgs.something ]   # platform-conditional list
config.lib.stylix.colors.base0D                # stylix base16 color (blue accent)
imports = [ inputs.some-flake.homeModules.default ];
host.mainMonitor.monitorID                     # e.g. "DP-2"
host.mainMonitor.monitorScalingFactor
```

## Profile System

All profile content lives in `modules/profiles/` (one tree, platform differences inside). Toggles are declared in `modules/profiles/default.nix`; enable per-host in `hosts/<name>/profiles.nix`.

**Profiles overview:** [`docs/profiles.md`](../docs/profiles.md) (structure + conventions; the tree is its own index).

```nix
dotfiles.profiles = {
  devenv.enable = true;        # headless dev core (tools, agents, podman CLI, languages)
  devgui.enable = true;        # GUI dev tooling (cursor/zed, podman-desktop)
  apps.enable = true;
  gaming.enable = true;        # Steam stack (Linux only)
  work.enable = true;          # Workato, Postman, browsers on Darwin
  llm.enable = true;           # serving stack (llama.cpp + unsloth); default off
  desktop.enable = true;       # niri + DMS + GNOME fallback (Linux only; default: true)
};
```

Always-on baselines (`enableOn`, the server opts out of the GUI halves): `minimal`, `essentials`, `fonts`(+`.full`), `theme`(+`.gui`).

Override selectively after `devenv.enable = true`:
```nix
dotfiles.profiles.devenv.languages.swift.enable = false;
```

## Where to Put Things

| What | Where |
|------|-------|
| Profile system packages (any platform) | `modules/profiles/<profile>.nix` — Linux/darwin extras inline via `lib.optionals (!isDarwin) [...]` |
| Profile config using Linux-only options (steam, flatpak, …) | Linux-only leaf in `modules/profiles/` (imported when `!isDarwin`, see `default.nix`) |
| macOS Homebrew casks/brews | `modules/profiles/work/darwin.nix` |
| Unconditional platform base (boot, networking, sops, …) | `modules/nixos/`, `modules/darwin/`, `modules/shared/` |
| Desktop / Wayland config | `modules/profiles/desktop/` |
| Language tooling | `modules/profiles/devenv/languages/<lang>.nix` |
| LLM agent tooling | `modules/profiles/devenv/agents/` |

## Gotchas

- **Conditional imports need a `default.nix` entry** — files not imported are silently ignored
- **Darwin: No nixpkgs Nix Daemon** — `modules/darwin/default.nix` sets `nix.enable = false`; Determinate installer manages the daemon; don't re-enable it

## Live Symlink Convention (HM halves)

For mutable app config that should live in git but remain writable by the app, store the file in the owning profile's folder and expose it with an out-of-store Home Manager symlink:

- Use `config.dotfiles.flakeRoot` for the repo path (option defined in `lib/home/dotfiles.nix`), never a hardcoded `/home/...` path.
- Use `mkLiveSymlink` from `lib/home/live-xdg-symlinks.nix` for both `home.file` and `xdg.configFile` entries. It sets `mkOutOfStoreSymlink` plus `force = true`.
- Do not use this for secrets, databases, logs, caches, or generated state.
- DMS/niri desktop config lives in `modules/profiles/desktop/{dms,niri}/` — edits take effect without a switch; verify with `just symlink-check`.
