{
  config,
  isDarwin ? false,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.work;
in {
  # ./darwin holds the homebrew side (+ cask app HM configs); the
  # `homebrew.*` namespace only exists on darwin, hence the import gate.
  imports = lib.optionals isDarwin [./darwin];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.postman
      pkgs.gws
      pkgs.workato-platform-cli
      pkgs.mise
    ];
  };
}
