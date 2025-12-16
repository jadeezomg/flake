{
  config,
  pkgs,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
in {
  programs.bash = {
    # Environment variables
    initExtra = ''
      # Flake configuration path
      export FLAKE="$HOME/.dotfiles/flake"

      # Common environment variables
      export EDITOR=${sharedEnv.commonEnv.EDITOR}
      export VISUAL=${sharedEnv.commonEnv.VISUAL}
      export BROWSER=${sharedEnv.commonEnv.BROWSER}
      export PAGER=${sharedEnv.commonEnv.PAGER}
      export BAT_THEME=${sharedEnv.commonEnv.BAT_THEME}

      # Add to PATH - include Nix system and user profile paths
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
    '';

    # Also set PATH for login shells
    profileExtra = ''
      # Add to PATH for login shells
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
    '';
  };
}
