{
  config,
  pkgs,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  programs.bash = {
    # Environment variables
    initExtra = ''
      # Flake configuration path
      export FLAKE=${sharedPaths.commonPaths.flake}
      # NH_FLAKE for nh (Nix Helper) - nh 4.2.0+ uses NH_FLAKE instead of FLAKE
      export NH_FLAKE=${sharedPaths.commonPaths.flake}

      # Common environment variables
      export EDITOR=${sharedEnv.commonEnv.EDITOR}
      export VISUAL=${sharedEnv.commonEnv.VISUAL}
      export BROWSER=${sharedEnv.commonEnv.BROWSER}
      export PAGER=${sharedEnv.commonEnv.PAGER}
      # BAT_THEME is optional now (Stylix can own it). Only export if present.
      ${pkgs.lib.optionalString (sharedEnv.commonEnv ? BAT_THEME) ''
        export BAT_THEME=${sharedEnv.commonEnv.BAT_THEME}
      ''}

      # Add to PATH - ensure /run/wrappers/bin stays first (contains setuid wrappers like sudo)
      # Then add our custom paths after the existing PATH
      export PATH="${sharedPaths.nixPaths.wrappersBin}:${sharedPaths.commonPaths.localBin}:${sharedPaths.commonPaths.cargoBin}:${sharedPaths.nixPaths.nixProfile}:${sharedPaths.nixPaths.userProfile}:${sharedPaths.nixPaths.systemSw}:${sharedPaths.nixPaths.defaultProfile}:$PATH"
    '';

    # Also set PATH for login shells
    profileExtra = ''
      # Add to PATH for login shells - ensure /run/wrappers/bin stays first
      export PATH="${sharedPaths.nixPaths.wrappersBin}:${sharedPaths.commonPaths.localBin}:${sharedPaths.commonPaths.cargoBin}:${sharedPaths.nixPaths.nixProfile}:${sharedPaths.nixPaths.userProfile}:${sharedPaths.nixPaths.systemSw}:${sharedPaths.nixPaths.defaultProfile}:$PATH"
    '';
  };
}
