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

**Profile → implementation file index:** [`docs/profiles.md`](../docs/profiles.md) (paths and one-line scope; package lists stay in the `.nix` sources).

```nix
dotfiles.profiles = {
  devenv.enable = true;        # enables all sub-profiles via lib.mkDefault
  apps.enable = true;
  gaming.enable = true;        # Steam stack (Linux only)
  work.enable = true;          # Workato, Postman, browsers on Darwin
  desktop.enable = true;       # niri + DMS + GNOME fallback (Linux only; default: true)
};
```

Override selectively after `devenv.enable = true`:
```nix
dotfiles.profiles.devenv.llm.hosting.enable = false;
dotfiles.profiles.devenv.languages.swift.enable = false;
```

## Where to Put Things

| What | Where |
|------|-------|
| Profile system packages (any platform) | `modules/profiles/<profile>.nix` — Linux/darwin extras inline via `lib.optionals (!isDarwin) [...]` |
| Profile config using Linux-only options (steam, flatpak, …) | Linux-only leaf in `modules/profiles/` (imported when `!isDarwin`, see `default.nix`) |
| macOS Homebrew casks/brews | `modules/profiles/work/darwin.nix` |
| Unconditional platform base (boot, networking, sops, …) | `modules/nixos/`, `modules/darwin/`, `modules/shared/` |
| Desktop / Wayland config | `modules/profiles/desktop.nix` |
| Language tooling | `modules/profiles/devenv/languages/<lang>.nix` |
| LLM agent tooling | `modules/profiles/devenv/llm/agents.nix` |

## Gotchas

- **Conditional imports need a `default.nix` entry** — files not imported are silently ignored
- **Darwin: No nixpkgs Nix Daemon** — `modules/darwin/default.nix` sets `nix.enable = false`; Determinate installer manages the daemon; don't re-enable it
