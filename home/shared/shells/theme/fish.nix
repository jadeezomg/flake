{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themePath = "$HOME/.config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
    programs.fish.interactiveShellInit = ''
      ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config ${themePath} | source
    '';
  }
