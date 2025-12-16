{
  config,
  pkgs,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  programs.fish = {
    # Environment variables - set via interactiveShellInit for Fish
    interactiveShellInit = ''
      # Disable Fish greeting
      set -U fish_greeting ""

      # Flake configuration path
      set -gx FLAKE ${sharedPaths.commonPaths.flake}

      # Common environment variables
      set -gx EDITOR ${sharedEnv.commonEnv.EDITOR}
      set -gx VISUAL ${sharedEnv.commonEnv.VISUAL}
      set -gx BROWSER ${sharedEnv.commonEnv.BROWSER}
      set -gx PAGER ${sharedEnv.commonEnv.PAGER}
      set -gx BAT_THEME ${sharedEnv.commonEnv.BAT_THEME}

      # Add to PATH - ensure /run/wrappers/bin stays first (contains setuid wrappers like sudo)
      # Then add our custom paths after the existing PATH
      set -gx PATH ${sharedPaths.nixPaths.wrappersBin} ${sharedPaths.commonPaths.localBin} ${sharedPaths.commonPaths.cargoBin} ${sharedPaths.nixPaths.nixProfile} ${sharedPaths.nixPaths.userProfile} ${sharedPaths.nixPaths.systemSw} ${sharedPaths.nixPaths.defaultProfile} $PATH
    '';
  };
}
