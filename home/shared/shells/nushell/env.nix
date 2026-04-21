{
  pkgs,
  lib,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
  sharedPaths = import ../shared/paths.nix;
  sharedConfig = import ../shared/config.nix;
  poshThemeRel = builtins.replaceStrings ["$HOME/"] [""] sharedConfig.ohMyPoshConfig.themePath;
in {
  programs.nushell = {
    environmentVariables =
      sharedEnv.commonEnv
      // {
        FLAKE = lib.hm.nushell.mkNushellInline ''$"($env.HOME)/.dotfiles/flake"'';
        NH_FLAKE = lib.hm.nushell.mkNushellInline ''$"($env.HOME)/.dotfiles/flake"'';
        ZED_ALLOW_ROOT = "true";
      };

    # Additional environment setup
    extraEnv = ''
      $env.PROMPT_COMMAND = {||
        let exit_code = (if ($env.LAST_EXIT_CODE) == null { 0 } else { $env.LAST_EXIT_CODE })
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print primary --config $"($env.HOME)/${poshThemeRel}" --shell nushell --status $exit_code
      }

      $env.PROMPT_COMMAND_RIGHT = {||
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print right --config $"($env.HOME)/${poshThemeRel}" --shell nushell
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

      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        "${sharedPaths.nixPaths.wrappersBin}"
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/.cargo/bin"
        $"($env.HOME)/.nix-profile/bin"
        "/etc/profiles/per-user/($env.USER)/bin"
        "${sharedPaths.nixPaths.systemSw}"
        "${sharedPaths.nixPaths.defaultProfile}"
      ])

      $env.NU_LIB_DIRS = [
        ($nu.default-config-dir | path join 'scripts')
        ($nu.data-dir | path join 'completions')
      ]

      # NU_PLUGIN_DIRS for plugin loading
      $env.NU_PLUGIN_DIRS = [
        ($nu.default-config-dir | path join 'plugins')
      ]

      if ($nu.is-interactive and $env.config.color_config? != null) {
        $env.config.color_config = ($env.config.color_config | upsert background '#372725')
      }
    '';
  };
}
