# nixpkgs imports for the whole flake, instantiated ONCE per system.
#
# `pkgsFor.<system>` holds the three channel imports (`pkgs`, `stable`,
# `small`). parts/hosts.nix exposes it as the flake-parts module arg `pkgsFor`
# so parts/packages.nix (perSystem `pkgs`) and every host's specialArgs +
# Home Manager extraSpecialArgs share the same attrsets instead of importing
# nixpkgs again. `genAttrs` is lazy: a system is only imported when read.
#
# The `getPkgs*` functions stay for callers and docs that name them; the
# default path (no extra overlays, no extra config) returns the memoized set.
# Only a host that passes `nixpkgsConfig` (hosts/framework/host.nix sets
# `rocmSupport`, a global feature flag that changes derivations everywhere,
# so it cannot be folded into the shared config) gets its own import through
# `getPkgsWithConfig`.
{ inputs, ... }:
let
  inherit (inputs) nixpkgs nixpkgs-small nixpkgs-stable;
  inherit (nixpkgs) lib;
  systems = import ./systems.nix;

  channelConfig = {
    allowUnfree = true;
    input-fonts.acceptLicense = true;
  };
  nixpkgsConfig = channelConfig // {
    permittedInsecurePackages = [
      "ventoy-1.1.17"
    ];
  };

  mkPkgs =
    system: extraOverlays: extraConfig:
    let
      baseOverlays = import ../parts/overlays/default.nix { inherit inputs system; };
      overlays = extraOverlays ++ baseOverlays;
    in
    import nixpkgs {
      inherit system overlays;
      config = nixpkgsConfig // extraConfig;
    };

  pkgsFor = lib.genAttrs systems (system: {
    pkgs = mkPkgs system [ ] { };
    stable = import nixpkgs-stable {
      inherit system;
      config = channelConfig;
    };
    small = import nixpkgs-small {
      inherit system;
      config = channelConfig;
    };
  });

  getPkgsWithConfig =
    system: extraOverlays: extraConfig:
    if extraOverlays == [ ] && extraConfig == { } then
      pkgsFor.${system}.pkgs
    else
      mkPkgs system extraOverlays extraConfig;
  getPkgs = system: extraOverlays: getPkgsWithConfig system extraOverlays { };
  getPkgsStable = system: pkgsFor.${system}.stable;
  getPkgsSmall = system: pkgsFor.${system}.small;
in
{
  inherit
    pkgsFor
    getPkgs
    getPkgsSmall
    getPkgsStable
    getPkgsWithConfig
    ;
}
