{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.data;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # YAML
      yaml-language-server

      # TOML
      taplo

      # XML
      lemminx

      # SQL
      sqlite
      sqls
    ];
  };
}
