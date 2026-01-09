{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-stable;

  getPkgs = system:
    import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
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
