{
  inputs,
  hostData,
  userData,
  userPreferences,
  userExtras,
  ...
}: let
  commonSpecialArgs =
    inputs
    // {
      inherit
        hostData
        userData
        userPreferences
        userExtras
        ;
      inherit inputs;
    };

  darwinSystems = ["aarch64-darwin"];

  # Shared home module sets
  baseHomeModules = isDarwin:
    if isDarwin
    then [
      ../../home/shared
      ../../home/darwin
    ]
    else [
      ../../home/shared
      ../../home/nixos
    ];
  homeModules = isDarwin:
    [
      inputs.sops-nix.homeManagerModules.sops
      inputs.stylix.homeModules.stylix
    ]
    # DMS is only for NixOS (Wayland), not Darwin
    ++ (
      if isDarwin
      then []
      else []
    )
    ++ baseHomeModules isDarwin;
in {
  inherit commonSpecialArgs darwinSystems homeModules;
}
