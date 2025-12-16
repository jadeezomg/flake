{
  config,
  pkgs,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
in {
  programs.nushell = {
    # Import common environment variables
    environmentVariables = sharedEnv.commonEnv;

    # Additional environment setup
    extraEnv = ''
      # Flake configuration path
      $env.FLAKE = $"($env.HOME)/.dotfiles/flake"

      let posh = "${pkgs.oh-my-posh}/bin/oh-my-posh"

      # Oh My Posh theme configuration - Custom Birds of Paradise theme (JSON format)
      let posh_theme = $"($env.HOME)/.config/oh-my-posh/birds-of-paradise.json"

      # Set up Oh My Posh prompt
      $env.PROMPT_COMMAND = {||
        let exit_code = (if ($env.LAST_EXIT_CODE) == null { 0 } else { $env.LAST_EXIT_CODE })
        ^$posh print primary --config $posh_theme --shell nushell --status $exit_code
      }

      $env.PROMPT_COMMAND_RIGHT = {||
        ^$posh print right --config $posh_theme --shell nushell
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

      # Set up PATH
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/.cargo/bin"
        $"($env.HOME)/.nix-profile/bin"
        "/etc/profiles/per-user/($env.USER)/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
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
