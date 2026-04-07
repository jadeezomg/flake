{
  lib,
  pkgs,
  isDarwin ? false,
  ...
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

  enabledFontPackages = lib.pipe fontDefinitions [
    (lib.mapAttrsToList (_: collectEnabledFonts))
    lib.flatten
  ];
in {
  # On Darwin, disable fontconfig and do not add font packages to home.packages.
  # Home Manager's Darwin font copy (Library/Fonts/HomeManager) builds a font env that
  # can fail with "cannot create directory .../share/fonts/woff" due to package layout.
  fonts.fontconfig.enable = !isDarwin;
  home.packages = lib.mkIf (!isDarwin) enabledFontPackages;

  # NOTE: List all installed fonts for debugging (NixOS only; Darwin skips font packages)
  home.file.".local/share/fonts-installed.txt" = lib.mkIf (!isDarwin) {
    text = let
      enabledFontsList = lib.pipe fontDefinitions [
        (lib.mapAttrsToList (
          categoryName: categoryFonts:
            lib.pipe categoryFonts [
              (lib.filterAttrs (_: isFontEnabled))
              (lib.mapAttrsToList (fontName: fontDef: "${categoryName}/${fontName}: ${fontDef.name}"))
            ]
        ))
        lib.flatten
        (lib.concatStringsSep "\n")
      ];
    in "# Installed Fonts\n# Generated automatically\n\n${enabledFontsList}\n";
  };
}
