{pkgs, ...}: {
  imports = [];

  # /bin/bash compat for scripts with hardcoded shebangs (e.g. third-party tools)
  environment.binsh = "${pkgs.bash}/bin/bash";

  # Linux-specific shell configuration
  programs = {
    command-not-found.enable = false; # Required for fish
    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
  };
  # Atuin is a shell history management tool that works across shells
  services.atuin.enable = true;
}
