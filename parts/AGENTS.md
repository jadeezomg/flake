# PARTS

flake-parts modules wiring the flake together.

## hosts.nix

Builds `nixosConfigurations` and `darwinConfigurations`. Key functions:

- **`mkHostOutputs hostKey host`** — builds per-host outputs; keys configurations by `host.hostname` (= `hostKey`)
- **`homeManagerConfig { user, hostKey, isDarwin, system, ... }`** — embedded HM config; passes `host`, `hostKey`, `isDarwin`, `pkgs`, `pkgs-stable` as `extraSpecialArgs`
- **`mkHomeManagerModule { hostKey, user, system, isDarwin }`** — wraps `homeManagerConfig` as a system module

## overlays/

- `default.nix` — central overlay list: local-packages + niri (x86_64-linux only) + cachyos kernel
- `local-packages.nix` — auto-registers `packages/*` as `pkgs.<name>` via `callPackage`
- `direnv-skip-check-darwin.nix` — patches direnv on Darwin

## Gotchas

- **Configurations keyed by `hostname`** — `nixosConfigurations.desktop`, `darwinConfigurations.caya`; fallback to `hostKey` if `hostname` unset
- **`nixpkgs-zed` is pinned** — does not follow `nixpkgs`; don't upgrade accidentally
- **`framework-control` has its own nixpkgs** — bundled fork; system-gated to `x86_64-linux`
