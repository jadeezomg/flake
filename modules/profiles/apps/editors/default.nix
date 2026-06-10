{
  config,
  lib,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.editors;
in {
  config = lib.mkIf cfg.enable {
    # HM half: helix config (+ ./helix settings tree). IDEs (cursor, zed)
    # live in devgui.ides — they're dev tooling, not "apps".
    home-manager.sharedModules = [./helix.nix];
  };
}
