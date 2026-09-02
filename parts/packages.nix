# Expose every local package (registered as `pkgs.<name>` by
# `parts/overlays/local-packages.nix`) as a flake `packages` output. The name
# list is shared via `packages/names.nix`.
#
# Also pins `perSystem`'s `pkgs` to our overlay-laden import — the memoized
# `pkgsFor.<system>.pkgs` from `lib/pkgs.nix`, published as a module arg by
# parts/hosts.nix, so it is the very same attrset the hosts evaluate with.
# This applies to all flake-parts perSystem modules, not just this one.
{ pkgsFor, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      pkgNames = import ../packages/names.nix {
        inherit system;
        inherit (pkgs) lib;
      };
    in
    {
      _module.args.pkgs = pkgsFor.${system}.pkgs;

      packages = pkgs.lib.genAttrs pkgNames (name: pkgs.${name});
    };
}
