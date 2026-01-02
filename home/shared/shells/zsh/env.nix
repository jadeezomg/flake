{
  config,
  pkgs,
  lib,
  ...
}: let
  sharedEnv = import ../shared/env.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  programs.zsh = {
    # Environment variables
    sessionVariables =
      sharedEnv.commonEnv
      // {
        FLAKE = sharedPaths.commonPaths.flake;
        NH_FLAKE = sharedPaths.commonPaths.flake;
      };

    # Additional environment setup
    initExtra = ''
      # Set up PATH - ensure /run/wrappers/bin stays first (contains setuid wrappers like sudo)
      # Then add our custom paths after the existing PATH
      export PATH="${sharedPaths.nixPaths.wrappersBin}:${sharedPaths.commonPaths.localBin}:${sharedPaths.commonPaths.cargoBin}:${sharedPaths.nixPaths.nixProfile}:${sharedPaths.nixPaths.userProfile}:${sharedPaths.nixPaths.systemSw}:${sharedPaths.nixPaths.defaultProfile}:$PATH"
    '';

    # Profile settings for login shells
    profileExtra = ''
      # Set up PATH for login shells
      export PATH="${sharedPaths.nixPaths.wrappersBin}:${sharedPaths.commonPaths.localBin}:${sharedPaths.commonPaths.cargoBin}:${sharedPaths.nixPaths.nixProfile}:${sharedPaths.nixPaths.userProfile}:${sharedPaths.nixPaths.systemSw}:${sharedPaths.nixPaths.defaultProfile}:$PATH"
    '';
  };
}
