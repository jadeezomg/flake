{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-stable;

  getPkgs = system: extraOverlays: let
    baseOverlays = import ../overlays/default.nix {inherit inputs system;};
    overlays = extraOverlays ++ baseOverlays;
  in
    import nixpkgs {
      inherit system;
      overlays = overlays;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        # Required by gvfs with Google Drive (see parts/overlays/gvfs-google-drive.nix)
        permittedInsecurePackages = ["libsoup-2.74.3"];
      };
    };

  getPkgsStable = system:
    import nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
      };
    };
in {
  inherit getPkgs getPkgsStable;
}
