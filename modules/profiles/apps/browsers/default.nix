# Browsers feature folder — zen is the daily driver (HM half in ./zen).
# firefox/chrome live in the work profile (homebrew casks on darwin).
{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.browsers;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [./zen];
  };
}
