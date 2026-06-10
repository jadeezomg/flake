# MODULES

System-level NixOS/Darwin configuration.

## Special Args Available in All Modules

```nix
{ pkgs, lib, config, inputs, hostData, hostKey, host, user, isDarwin, system, pkgs-small, pkgs-stable }
```

- `hostKey` — `"desktop"`, `"framework"`, or `"caya"` (use for host conditionals)
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

All toggles live in `modules/shared/profiles/default.nix`. Enable per-host in `hosts/<name>/profiles.nix`.

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
| System packages (all hosts) | `modules/shared/profiles/<profile>.nix` |
| System packages (all NixOS) | `modules/nixos/profiles/<profile>.nix` |
| System packages (all Darwin) | `modules/darwin/default.nix` (e.g. Homebrew when `work.enable`) |
| NixOS services / daemons | `modules/nixos/` |
| Desktop / Wayland config | `modules/nixos/profiles/desktop.nix` |
| Language tooling | `modules/shared/profiles/devenv/languages/<lang>.nix` |
| LLM agent tooling | `modules/shared/profiles/devenv/llm/agents.nix` |

## Gotchas

- **Conditional imports need a `default.nix` entry** — files not imported are silently ignored
- **Darwin: No nixpkgs Nix Daemon** — `modules/darwin/default.nix` sets `nix.enable = false`; Determinate installer manages the daemon; don't re-enable it
