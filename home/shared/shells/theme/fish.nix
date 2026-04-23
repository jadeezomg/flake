{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themePath = "$HOME/.config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf ((osConfig.dotfiles.profiles.essentials.enable or true)
    && (osConfig.dotfiles.profiles.essentials.promptEngine or "oh-my-posh") == "oh-my-posh") {
    programs.fish.interactiveShellInit = ''
      ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config ${themePath} | source
    '';
  }
