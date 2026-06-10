{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.comms;
in {
  config = lib.mkIf cfg.enable {
    # Linux-only; darwin comms (slack, …) come via the work profile's homebrew.
    environment.systemPackages = lib.optionals (!isDarwin) [pkgs.protonmail-desktop];
  };
}
