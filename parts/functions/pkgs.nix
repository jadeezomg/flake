{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-unstable nur;

  # Helper to get unstable pkgs for a system (needed for config args)
  getPkgsUnstable = system:
    import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
      };
      overlays = [
        nur.overlays.default
      ];
    };

  # Helper to get pkgs for a system (used in host logic)
  getPkgs = system:
    import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
      };
      overlays = [
        nur.overlays.default
      ];
    };
in {
  inherit getPkgs getPkgsUnstable;
}
