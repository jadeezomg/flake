{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.work;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.postman
      pkgs.gws
      pkgs.workato-platform-cli
    ];
  };
}
