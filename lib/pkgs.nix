{ inputs, ... }:
let
  inherit (inputs) nixpkgs nixpkgs-small nixpkgs-stable;

  mkPkgs =
    system: extraOverlays: extraConfig:
    let
      baseOverlays = import ../parts/overlays/default.nix { inherit inputs system; };
      overlays = extraOverlays ++ baseOverlays;
    in
    import nixpkgs {
      inherit system;
      inherit overlays;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        permittedInsecurePackages = [
          "ventoy-1.1.12"
        ];
      }
      // extraConfig;
    };

  getPkgs = system: extraOverlays: mkPkgs system extraOverlays { };
  getPkgsWithConfig =
    system: extraOverlays: extraConfig:
    mkPkgs system extraOverlays extraConfig;

  getPkgsStable =
    system:
    import nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
      };
    };
  getPkgsSmall =
    system:
    import nixpkgs-small {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
      };
    };
in
{
  inherit
    getPkgs
    getPkgsSmall
    getPkgsStable
    getPkgsWithConfig
    ;
}
