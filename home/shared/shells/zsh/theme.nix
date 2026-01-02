{
  config,
  pkgs,
  ...
}: let
  sharedConfig = import ../shared/config.nix;
in {
  # Configure Oh My Posh for Zsh
  programs.zsh = {
    initExtra = ''
      # Initialize Oh My Posh (skip in Apple Terminal)
      if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${sharedConfig.ohMyPoshConfig.themePath})"
      fi
    '';
  };
}
