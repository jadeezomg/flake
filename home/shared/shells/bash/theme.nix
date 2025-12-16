{
  config,
  pkgs,
  ...
}: let
  sharedConfig = import ../shared/config.nix;
in {
  # Configure Oh My Posh for Bash
  programs.bash = {
    # For login shells, ensure .bashrc is sourced
    profileExtra = ''
      # Source .bashrc if it exists (for login shells)
      [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
    '';
    # For interactive non-login shells
    initExtra = ''
      # Initialize Oh My Posh
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config ${sharedConfig.ohMyPoshConfig.themePath})"
    '';
  };
}
