{
  pkgs,
  lib,
  ...
}: let
  aliases = (import ./data/aliases.nix).commonAliases;
  paths = (import ./data/paths.nix).commonPaths;
in {
  programs.fish = {
    enable = true;
    shellAliases =
      aliases
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        trash = "gio trash";
      };

    interactiveShellInit = ''
      set -U fish_greeting ""

      function zz
        cd ${paths.home}
      end
      function zc
        cd ${paths.config}
      end
      function zd
        cd ${paths.downloads}
      end
    '';
  };
}
