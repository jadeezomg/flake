{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.dotfiles.profiles.work;
  system = pkgs.stdenv.hostPlatform.system;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.postman
      inputs.google-workspace-cli.packages.${system}.default
      pkgs.workato-platform-cli
    ];
  };
}
