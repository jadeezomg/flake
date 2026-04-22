{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themePath = "$HOME/.config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
    programs.zsh.initContent = ''
      if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${themePath})"
      fi
    '';
  }
