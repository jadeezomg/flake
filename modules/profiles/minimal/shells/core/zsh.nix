{
  dotfilesLib,
  config,
  pkgs,
  lib,
  ...
}: let
  aliases = (import ./data/aliases.nix).commonAliases;
  paths = dotfilesLib.shellPaths.commonPaths;
in {
  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreAllDups = true;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    shellAliases =
      aliases
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        trash = "gio trash";
      };

    initContent = ''
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward
      bindkey '^[w' kill-region

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' menu no

      zz() { cd ${paths.home}; }
      zc() { cd ${paths.config}; }
      zd() { cd ${paths.downloads}; }
      p() {
        pi -p "$*"
      }
    '';
  };
}
