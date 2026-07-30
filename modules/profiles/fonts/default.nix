# Fonts baseline — exactly the fonts Stylix references, guaranteed present
# wherever Stylix renders (fixes the latent gap where "Inter Variable" had no
# package). Always on, including the server; the full catalogue is ./full.nix.
{
  config,
  dotfilesLib,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.fonts;
  themeFonts = dotfilesLib.themeFonts { inherit pkgs; };
in
{
  imports = [ ./full.nix ];

  config = lib.mkIf cfg.enable {
    fonts.packages = map (font: font.package) [
      themeFonts.monospace
      themeFonts.serif
      themeFonts.sansSerif
      themeFonts.emoji
    ];

    # User-level fontconfig integration — previously enabled by the deleted
    # HM font installer (home/shared/assets/fonts/install.nix) on Linux; HM
    # still installs fonts of its own (e.g. Stylix's), so keep it.
    home-manager.sharedModules = lib.optionals (!isDarwin) [ ./fontconfig.nix ];
  };
}
