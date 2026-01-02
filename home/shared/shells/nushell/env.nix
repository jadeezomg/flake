{
  config,
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
      };

    # Additional environment setup
    extraEnv = ''

      # OLD: Variables defined outside the closure aren't accessible inside
      # let posh = "${pkgs.oh-my-posh}/bin/oh-my-posh"
      # let posh_theme = $"($env.HOME)/${poshThemeRel}"

      # Set up Oh My Posh prompt
      # NOTE: Using full paths directly in closures since variables aren't captured
      $env.PROMPT_COMMAND = {||
        let exit_code = (if ($env.LAST_EXIT_CODE) == null { 0 } else { $env.LAST_EXIT_CODE })
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print primary --config $"($env.HOME)/${poshThemeRel}" --shell nushell --status $exit_code
      }

      $env.PROMPT_COMMAND_RIGHT = {||
        ^"${pkgs.oh-my-posh}/bin/oh-my-posh" print right --config $"($env.HOME)/${poshThemeRel}" --shell nushell
      }

      # Prompt indicators - set to empty since Oh My Posh handles the prompt
      $env.PROMPT_INDICATOR = {|| "" }
      $env.PROMPT_INDICATOR_VI_INSERT = {|| "" }
      $env.PROMPT_INDICATOR_VI_NORMAL = {|| "" }
      $env.PROMPT_MULTILINE_INDICATOR = {|| "::: " }

      # Specifies how environment variables are:
      # - converted from a string to a value on Nushell startup (from_string)
      # - converted from a value back to a string when running external commands (to_string)
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

      # Set up PATH - ensure /run/wrappers/bin stays first (contains setuid wrappers like sudo)
      # Then add our custom paths after the existing PATH
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        "${sharedPaths.nixPaths.wrappersBin}"
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/.cargo/bin"
        $"($env.HOME)/.nix-profile/bin"
        "/etc/profiles/per-user/($env.USER)/bin"
        "${sharedPaths.nixPaths.systemSw}"
        "${sharedPaths.nixPaths.defaultProfile}"
      ])

      # NU_LIB_DIRS for module loading
      $env.NU_LIB_DIRS = [
        ($nu.default-config-dir | path join 'scripts')
        ($nu.data-dir | path join 'completions')
      ]

      # NU_PLUGIN_DIRS for plugin loading
      $env.NU_PLUGIN_DIRS = [
        ($nu.default-config-dir | path join 'plugins')
      ]

      # Override Birds of Paradise theme background to match Cursor theme
      # This runs after the theme's export-env block, ensuring our override takes effect
      # Note: The actual color value is set in theme.nix, but we keep this as a fallback
      if ($env.config.color_config? != null) {
        $env.config.color_config = ($env.config.color_config | upsert background '#372725')
        # Update terminal background color via OSC sequence
        let osc_screen_background_color = '11;'
        print -n $"(ansi -o $osc_screen_background_color)#372725(char bel)\r"
      }
    '';
  };
}
