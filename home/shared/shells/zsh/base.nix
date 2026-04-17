{config, ...}: {
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

      flake() {
        local j="''${FLAKE:?}/Justfile" c
        case "$1" in
          build|switch|generation|gc|fmt|backups)
            [[ $# -le 1 ]] || { c="$1"; shift; command just --justfile "$j" "_$c" "$@"; return }
            ;;
          init)
            [[ $# -le 1 ]] || { shift; command just --justfile "$j" _init "$@"; return }
            ;;
          read-defaults)
            [[ $# -le 1 ]] || { shift; command just --justfile "$j" _read-defaults "$@"; return }
            ;;
        esac
        command just --justfile "$j" "$@"
      }
      nuflake() { command nu "''${FLAKE:?}/build/flake.nu" "$@"; }
    '';
  };
}
