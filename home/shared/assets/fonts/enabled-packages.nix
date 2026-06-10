# Flattens every `enable = true` font definition in ./fonts.nix (main
# package + extraPackages) into a single list of packages.
#
# Shared by two consumers so the font catalogue is defined exactly once:
#   - ./install.nix          → home.packages on Linux (Home Manager)
#   - modules/darwin/fonts.nix → fonts.packages on macOS (nix-darwin)
{
  lib,
  pkgs,
}: let
  fontDefinitions = import ./fonts.nix {inherit pkgs;};
  isFontEnabled = fontDef: fontDef ? enable && fontDef.enable == true;

  getFontPackages = fontDef: let
    mainPackage = lib.optional (fontDef.package != null) fontDef.package;
    extraPackages = fontDef.extraPackages or [];
  in
    mainPackage ++ extraPackages;

  collectEnabledFonts = categoryFonts:
    lib.pipe categoryFonts [
      (lib.filterAttrs (_: isFontEnabled))
      (lib.mapAttrsToList (_: getFontPackages))
      lib.flatten
    ];
in
  lib.pipe fontDefinitions [
    (lib.mapAttrsToList (_: collectEnabledFonts))
    lib.flatten
  ]
