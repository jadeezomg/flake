{
  pkgs,
  lib,
  ...
}: let
  aliases = (import ./data/aliases.nix).commonAliases;
  paths = (import ./data/paths.nix).commonPaths;

  configRel = builtins.replaceStrings ["$HOME/"] [""] paths.config;
  downloadsRel = builtins.replaceStrings ["$HOME/"] [""] paths.downloads;

  gitNu = pkgs.fetchFromGitHub {
    owner = "fj0r";
    repo = "git.nu";
    rev = "main";
    sha256 = "sha256-7twPTScOXW8RqgDAKx0mzwYVeQrmj3cP9dFO9PBRclA=";
  };

  bashEnvNu = pkgs.fetchFromGitHub {
    owner = "tesujimath";
    repo = "bash-env-nushell";
    rev = "main";
    sha256 = "sha256-iNskiGPB4PANxlnCMzAxqkkwfsukWR5AFW5o86g/oP8=";
  };
in {
  programs.nushell = {
    enable = true;
    shellAliases =
      aliases
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        trash = "gio trash";
      };

    settings = {
      show_banner = false;

      history = {
        max_size = 100000;
        sync_on_enter = true;
        file_format = "sqlite";
        isolation = false;
      };

      completions = {
        case_sensitive = false;
        quick = true;
        partial = true;
        algorithm = "fuzzy";
        external = {
          enable = true;
          max_results = 100;
          completer = null;
        };
      };
    };

    extraConfig = ''
      use ${gitNu}/git/mod.nu *
      use ${gitNu}/git/shortcut.nu *
      use ${bashEnvNu}/bash-env.nu *

      def --env zz [] { cd ''$env.HOME }
      def --env zc [] { cd $"(''$env.HOME)/${configRel}" }
      def --env zd [] { cd $"(''$env.HOME)/${downloadsRel}" }
    '';
  };

  home.packages = [pkgs.bash-env-json];
}
