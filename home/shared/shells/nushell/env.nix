{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Build nu_plugin_tree from source
  nu-plugin-tree = pkgs.rustPlatform.buildRustPackage rec {
    pname = "nu-plugin-tree";
    version = "0.1.0";
    src = inputs.nu-plugin-tree;

    # Let Nix handle cargo dependencies
    # This will work if Cargo.lock exists, otherwise you'll need to provide cargoSha256
    cargoLock.lockFile = "${src}/Cargo.lock";

    nativeBuildInputs = with pkgs; [
      rustc
      cargo
    ];

    # Standard build - buildRustPackage handles this automatically
    # But we can override if needed
    doCheck = false; # Skip tests for faster builds
  };
in
{
  programs.nushell = {
    environmentVariables = {
      EDITOR = "zeditor";
      VISUAL = "zeditor";
      BROWSER = "zen";
      PAGER = "bat";

      BAT_THEME = "TwoDark";
    };

    # Additional environment setup
    extraEnv = ''
      # Flake configuration path
      $env.FLAKE = $"($env.HOME)/.dotfiles/flake"

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
        "${nu-plugin-tree}/bin"
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
