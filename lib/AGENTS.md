# LIB

Shared Nix helpers used across the flake.

## pkgs.nix

```nix
getPkgs system extraOverlays   # nixpkgs with allowUnfree + all overlays + extraOverlays
getPkgsStable system           # nixpkgs 25.11, allowUnfree, NO overlays
```

Imported in `parts/hosts.nix`; passed as `pkgs` / `pkgs-stable` to all modules.

## home/live-xdg-symlinks.nix

Helper for creating live (out-of-store) symlinks to XDG config directories. Used by desktop config so niri/DMS edits take effect without a switch.

