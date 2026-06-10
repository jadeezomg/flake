# Theme feature folder — system half. The HM halves are pushed via
# sharedModules: ./home.nix always (CLI/shell theming, base16 palette),
# ./gui.nix only for theme.gui hosts (wallpaper, cursor, GTK, symlinks).
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.theme;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules =
      [./home.nix]
      ++ lib.optionals cfg.gui.enable [./gui.nix];
  };
}
