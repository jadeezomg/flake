# Fonts baseline — exactly the fonts Stylix references, guaranteed present
# wherever Stylix renders (fixes the latent gap where "Inter Variable" had no
# package). Always on, including the server; the full catalogue is ./full.nix.
{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.fonts;
in {
  imports = [./full.nix];

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      nerd-fonts.iosevka # stylix monospace
      iosevka-etoile # stylix serif (local package via overlay)
      inter # stylix sans-serif ("Inter Variable")
      noto-fonts-color-emoji # stylix emoji
    ];

    # User-level fontconfig integration — previously enabled by the deleted
    # HM font installer (home/shared/assets/fonts/install.nix) on Linux; HM
    # still installs fonts of its own (e.g. Stylix's), so keep it.
    home-manager.sharedModules = lib.optionals (!isDarwin) [./home.nix];
  };
}
