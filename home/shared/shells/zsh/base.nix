{
  config,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;

    # General settings
    enableCompletion = true;
    autosuggestion.enable = false; # Disabled - causes remnant characters with oh-my-posh
    syntaxHighlighting.enable = true;

    # History settings
    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreAllDups = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    # Completion configuration
    initContent = ''
      # Key bindings
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward
      bindkey '^[w' kill-region

      # Completion styling
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' menu no

      # pay-respects integration
      alias f='eval $(_PR_LAST_COMMAND="$(fc -ln -1)" _PR_ALIAS="`alias`" _PR_SHELL="zsh" "pay-respects")'

      command_not_found_handler() {
        eval $(_PR_LAST_COMMAND="$@" _PR_SHELL="zsh" _PR_ALIAS="`alias`" _PR_MODE="cnf" "pay-respects")
      }
    '';
  };
}
