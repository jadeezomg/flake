{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.databases;
in {
  config = lib.mkIf cfg.enable {
    # Database client tooling. Server daemons (postgresql, redis) live in
    # dotfiles.profiles.server (parked, no host enables it yet).
    environment.systemPackages = with pkgs; [
      rainfrog # TUI client
    ];
  };
}
