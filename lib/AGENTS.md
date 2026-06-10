# LIB

Shared Nix helpers used across the flake.

## pkgs.nix

```nix
getPkgs system extraOverlays                         # nixpkgs with allowUnfree + all overlays + extraOverlays
getPkgsWithConfig system extraOverlays extraConfig   # same, plus host-specific nixpkgs config (e.g. rocmSupport)
getPkgsSmall system                                  # nixpkgs-unstable-small, allowUnfree, NO overlays
getPkgsStable system                                 # nixpkgs 25.11, allowUnfree, NO overlays
```

Imported in `parts/hosts.nix`; passed as `pkgs` / `pkgs-small` / `pkgs-stable` to all modules.

## home/live-xdg-symlinks.nix

Helper for creating live (out-of-store) symlinks to XDG config directories. Used by desktop config so niri/DMS edits take effect without a switch.

## home/dotfiles.nix

HM module defining `dotfiles.flakeRoot` (path to the live checkout; defaults to `~/.dotfiles/flake`). Imported unconditionally for every user via `parts/hosts.nix` `homeModules` — every `mkOutOfStoreSymlink`/live-symlink target builds on it.

