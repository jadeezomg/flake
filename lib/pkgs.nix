{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-stable;

  getPkgs = system: extraOverlays: let
    baseOverlays = import ../parts/overlays/default.nix {inherit inputs system;};
    overlays = extraOverlays ++ baseOverlays;
  in
    import nixpkgs {
      inherit system;
      overlays = overlays;
      config = {
        allowUnfree = true;
        input-fonts.acceptLicense = true;
        permittedInsecurePackages = ["ventoy-1.1.12" "python3.13-vllm-0.16.0"];
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
