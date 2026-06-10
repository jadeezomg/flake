# Expose every local package (registered as `pkgs.<name>` by
# `parts/overlays/local-packages.nix`) as a flake `packages` output. The name
# list is shared via `packages/names.nix`.
#
# Also pins `perSystem`'s `pkgs` to our overlay-laden import (`lib/pkgs.nix`)
# — this applies to all flake-parts perSystem modules, not just this one.
{inputs, ...}: let
  pkgsFuncs = import ../lib/pkgs.nix {inherit inputs;};
  inherit (pkgsFuncs) getPkgs;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    pkgNames = import ../packages/names.nix {
      inherit system;
      lib = pkgs.lib;
    };
  in {
    _module.args.pkgs = getPkgs system [];

    packages = pkgs.lib.genAttrs pkgNames (name: pkgs.${name});
  };
}
