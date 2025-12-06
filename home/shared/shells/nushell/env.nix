{ config, pkgs, ... }:

{
  programs.nushell = {
    # Environment variables
    environmentVariables = {
      # Default applications
      EDITOR = "zeditor";
      VISUAL = "zeditor";
      BROWSER = "zen";
      PAGER = "bat";

      # Application settings
      BAT_THEME = "TwoDark";
    };

    # Additional environment setup
    extraEnv = ''
      let posh = "${pkgs.oh-my-posh}/bin/oh-my-posh"
      
      # Oh My Posh theme configuration
      # Available themes: https://ohmyposh.dev/docs/themes
      let posh_theme = "tiwahu"
      
      # Set up Oh My Posh prompt
      $env.PROMPT_COMMAND = {|| 
        let exit_code = (if ($env.LAST_EXIT_CODE) == null { 0 } else { $env.LAST_EXIT_CODE })
        ^$posh print primary --config $posh_theme --shell nushell --status $exit_code
      }
      
      $env.PROMPT_COMMAND_RIGHT = {|| 
        ^$posh print right --config $posh_theme --shell nushell
      }
      
      # Prompt indicators
      $env.PROMPT_INDICATOR = {|| "> " }
      $env.PROMPT_INDICATOR_VI_INSERT = {|| ": " }
      $env.PROMPT_INDICATOR_VI_NORMAL = {|| "> " }
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
    '';
  };
}

