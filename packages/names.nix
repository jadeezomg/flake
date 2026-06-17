# Single source for the local-package name list: every `packages/<name>/`
# directory with a `default.nix`, minus per-package system gates. Consumed by
# `parts/overlays/local-packages.nix` (overlay registration) and
# `parts/packages.nix` (flake `packages` output) so the two can't drift.
{lib, ...}: let
  pkgRoot = ./.;

  isLocalPkg = name: type: type == "directory" && builtins.pathExists (pkgRoot + "/${name}/default.nix");
in
  builtins.attrNames (lib.filterAttrs isLocalPkg (builtins.readDir pkgRoot))
