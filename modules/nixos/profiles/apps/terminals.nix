{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.terminals;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      alacritty
      ghostty
      kitty
    ];
  };
}
