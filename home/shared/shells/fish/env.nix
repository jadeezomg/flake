{
  config,
  pkgs,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
in {
  programs.fish = {
    # Environment variables - set via interactiveShellInit for Fish
    interactiveShellInit = ''
      # Flake configuration path
      set -gx FLAKE "$HOME/.dotfiles/flake"

      # Common environment variables
      set -gx EDITOR ${sharedEnv.commonEnv.EDITOR}
      set -gx VISUAL ${sharedEnv.commonEnv.VISUAL}
      set -gx BROWSER ${sharedEnv.commonEnv.BROWSER}
      set -gx PAGER ${sharedEnv.commonEnv.PAGER}
      set -gx BAT_THEME ${sharedEnv.commonEnv.BAT_THEME}

      # Add to PATH - include Nix system and user profile paths
      set -gx PATH $HOME/.local/bin $HOME/.cargo/bin $HOME/.nix-profile/bin /etc/profiles/per-user/$USER/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin $PATH
    '';
  };
}
