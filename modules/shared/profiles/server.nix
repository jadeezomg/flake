{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.server;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      postgresql
      redis
    ];
  };
}
