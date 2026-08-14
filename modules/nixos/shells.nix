{ pkgs, ... }: {
  # /bin/bash compat for scripts with hardcoded shebangs (third-party tools)
  environment.binsh = "${pkgs.bash}/bin/bash";

  programs = {
    command-not-found.enable = false; # nix-index owns the command-not-found hook
    nix-index.enable = true;
  };
}
