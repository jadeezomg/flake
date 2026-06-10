# PARTS

flake-parts modules wiring the flake together.

## hosts.nix

Builds `nixosConfigurations` and `darwinConfigurations`. Key functions:

- **`mkHostOutputs hostKey host`** — builds per-host outputs; keys configurations by `host.hostname` (= `hostKey`); imports only modules common to every host of a platform (single-host modules live in `hosts/<name>/default.nix`)
- **`homeManagerConfig { user, hostKey, isDarwin, system, ... }`** — embedded HM config; passes `host`, `hostKey`, `isDarwin`, `pkgs`, `pkgs-small`, `pkgs-stable` as `extraSpecialArgs`
- **`homeModules`** — flat unconditional base (sops + stylix HM modules + `lib/home/dotfiles.nix`); all other user config arrives via `home-manager.sharedModules` pushed by profiles
- **`mkHomeManagerModule { hostKey, user, system, isDarwin }`** — wraps `homeManagerConfig` as a system module

## packages.nix / checks.nix / lib.nix

- `packages.nix` — exposes every local package as `packages.<system>.<name>` from `pkgs.<name>` (name list shared with the overlay via `packages/names.nix`); also pins `perSystem`'s `pkgs` to the overlay-laden import
- `checks.nix` — `mcp-servers` (eval-asserted), `host-caya-eval` (darwin toplevel eval; flake check ignores darwinConfigurations), `host-mini-headless` (server stays headless); `formatter = alejandra`
- `lib.nix` — `flake.lib.skillsUpstreamSrc` for `just skills-upstream`

## overlays/

- `default.nix` — central overlay list: local-packages + niri (x86_64-linux only) + cachyos kernel
- `local-packages.nix` — auto-registers `packages/*` as `pkgs.<name>` via `callPackage` (name list from `packages/names.nix`)
- `direnv-skip-check-darwin.nix` — patches direnv on Darwin

## Gotchas

- **Configurations keyed by `hostname`** — `nixosConfigurations.desktop`, `darwinConfigurations.caya`; fallback to `hostKey` if `hostname` unset
- **`nixpkgs-zed` is pinned** — does not follow `nixpkgs`; don't upgrade accidentally
- **`framework-control` has its own nixpkgs** — bundled fork; system-gated to `x86_64-linux`
