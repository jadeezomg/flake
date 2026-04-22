{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themePath = "$HOME/.config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
    programs.bash = {
      profileExtra = ''
        [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
      '';
      initExtra = ''
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config ${themePath})"
      '';
    };
  }
