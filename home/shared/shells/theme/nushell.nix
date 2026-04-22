{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  themeColors = import ../../assets/theme/theme.nix;
  themePathRel = ".config/oh-my-posh/birds-of-paradise.json";
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
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

      $env.ENV_CONVERSIONS = {
        "PATH": {
          from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
          to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
        }
        "Path": {
          from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
          to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
        }
      }

      $env.NU_LIB_DIRS = [
        ($nu.default-config-dir | path join 'scripts')
        ($nu.data-dir | path join 'completions')
      ]

      $env.NU_PLUGIN_DIRS = [
        ($nu.default-config-dir | path join 'plugins')
      ]

      if ($nu.is-interactive and $env.config.color_config? != null) {
        $env.config.color_config = ($env.config.color_config | upsert background '#372725')
      }
    '';

    programs.nushell.extraConfig = ''
      if $nu.is-interactive {
        ^sh -c 'test -t 1'
        if $env.LAST_EXIT_CODE == 0 {
          source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu
          $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')
        }
      }
    '';
  }
