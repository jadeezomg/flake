{
  config,
  dotfilesLib,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.notes;
  typoraTheme = import ./typora-theme.nix {
    inherit (dotfilesLib) palette;
  };
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optionals (!isDarwin) [pkgs.typora];

    home-manager.sharedModules = [
      {
        xdg.configFile."Typora/themes/birds-of-paradise.css".text = typoraTheme;
      }
    ];
  };
}
