{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themePathRel = ".config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf ((osConfig.dotfiles.profiles.essentials.enable or true)
    && (osConfig.dotfiles.profiles.essentials.promptEngine or "oh-my-posh") == "oh-my-posh") {
    programs.nushell.extraEnv = ''
      $env.PROMPT_COMMAND = {||
        let exit_code = (if ($env.LAST_EXIT_CODE) == null { 0 } else { $env.LAST_EXIT_CODE })
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print primary --config $"($env.HOME)/${themePathRel}" --shell nushell --status $exit_code
      }

      $env.PROMPT_COMMAND_RIGHT = {||
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print right --config $"($env.HOME)/${themePathRel}" --shell nushell
      }

      $env.PROMPT_INDICATOR = {|| "" }
      $env.PROMPT_INDICATOR_VI_INSERT = {|| "" }
      $env.PROMPT_INDICATOR_VI_NORMAL = {|| "" }
      $env.PROMPT_MULTILINE_INDICATOR = {|| "::: " }
    '';
  }
