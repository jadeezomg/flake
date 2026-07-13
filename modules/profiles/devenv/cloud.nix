{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.cloud;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      awscli2
      awslogs
      flarectl
    ];
  };
}
