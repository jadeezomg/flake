# Theme feature folder — system half. The HM halves are pushed via
# sharedModules: ./stylix.nix always (CLI/shell theming, base16 palette),
# ./gui.nix and ./qt-kde.nix only for theme.gui hosts (wallpaper, cursor, GTK,
# symlinks, and the Qt/KDE palette Stylix cannot supply outside Plasma).
{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.theme;
in
{
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ./stylix.nix
    ]
    ++ lib.optionals cfg.gui.enable [
      ./gui.nix
      ./qt-kde.nix
    ];
  };
}
