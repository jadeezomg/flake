{pkgs, ...}: {
  # /bin/bash compat for scripts with hardcoded shebangs (third-party tools)
  environment.binsh = "${pkgs.bash}/bin/bash";

  programs = {
    command-not-found.enable = false; # Required for fish
    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  # Shell history sync across shells; service-style on NixOS only.
  services.atuin.enable = true;
}
