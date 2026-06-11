{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.editors;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [./helix.nix];
  };
}
