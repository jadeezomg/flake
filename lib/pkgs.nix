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
      overlays = overlays;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        # Deliberately here and not in an overlay: an overlay cannot grant an
        # insecure-package exception, and dropping ventoy's
        # `meta.knownVulnerabilities` to fake one would hide the warning globally.
        # This form is version-pinned on purpose — a nixpkgs bump past 1.1.12
        # fails the build loudly instead of silently extending the exception.
        # ventoy ships unauditable binary blobs (nixpkgs#404663); used by
        # modules/profiles/apps/files.
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
