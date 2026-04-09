{pkgs, ...}: let
  sharedEnv = import ../shared/env.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  programs.fish = {
    # Environment variables - set via interactiveShellInit for Fish
    interactiveShellInit = ''
      set -U fish_greeting ""

      # GitHub token for Nix (from sops secret at ~/.config/nix/github-token)
      if test -f $HOME/.config/nix/github-token
        set -gx NIX_CONFIG "access-tokens = github.com="(cat $HOME/.config/nix/github-token | string trim)" $NIX_CONFIG"
      end

      set -gx FLAKE ${sharedPaths.commonPaths.flake}
      set -gx NH_FLAKE ${sharedPaths.commonPaths.flake}
      set -gx ZED_ALLOW_ROOT true
      set -gx EDITOR ${sharedEnv.commonEnv.EDITOR}
      set -gx VISUAL ${sharedEnv.commonEnv.VISUAL}
      set -gx BROWSER ${sharedEnv.commonEnv.BROWSER}
      set -gx PAGER ${sharedEnv.commonEnv.PAGER}
      # BAT_THEME is optional now (Stylix can own it). Only export if present.
      ${pkgs.lib.optionalString (sharedEnv.commonEnv ? BAT_THEME) ''
        set -gx BAT_THEME ${sharedEnv.commonEnv.BAT_THEME}
      ''}

      # Add to PATH - ensure /run/wrappers/bin stays first (contains setuid wrappers like sudo)
      # Then add our custom paths after the existing PATH
      set -gx PATH ${sharedPaths.nixPaths.wrappersBin} ${sharedPaths.commonPaths.localBin} ${sharedPaths.commonPaths.cargoBin} ${sharedPaths.nixPaths.nixProfile} ${sharedPaths.nixPaths.userProfile} ${sharedPaths.nixPaths.systemSw} ${sharedPaths.nixPaths.defaultProfile} $PATH
    '';
  };
}
