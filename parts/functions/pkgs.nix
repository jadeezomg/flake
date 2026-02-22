{inputs, ...}: let
  inherit (inputs) nixpkgs nixpkgs-stable;

  # CachyOS kernel overlay applied automatically for x86_64-linux.
  getPkgs = system: extraOverlays:
    let
      cachyosOverlay =
        if system == "x86_64-linux"
        then [inputs.nix-cachyos-kernel.overlays.pinned]
        else [];
      overlays = extraOverlays ++ cachyosOverlay;
    in
    import nixpkgs {
      inherit system;
      overlays = overlays;
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
