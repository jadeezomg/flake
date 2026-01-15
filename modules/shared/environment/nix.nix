{
  config,
  pkgs,
  lib,
  ...
}: let
  numCores = config.nixpkgs.hostPlatform.numCores or 8;
  numCoresInt =
    if builtins.isInt numCores
    then numCores
    else builtins.floor numCores;
  coresPerBuild = lib.min 3 (lib.max 1 (builtins.floor (numCoresInt / 4)));
  maxTotalCores = builtins.floor (numCoresInt * 0.5);
  maxJobs = lib.max 1 (builtins.floor (maxTotalCores / coresPerBuild));
  buildCores = coresPerBuild;
  buildJobs = maxJobs;
in {
  nix.settings = {
    download-buffer-size = 524288000; # 500 MiB
    max-jobs = buildJobs;
    cores = buildCores;

    # if build failes because of public keys
    # cd /home/jadee/.dotfiles/flake && sudo NIX_CONFIG='substituters = https://cache.nixos.org/ trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' nix build '.#nixosConfigurations.desktop.config.system.build.toplevel'
    # sudo nixos-rebuild switch --flake /home/jadee/.dotfiles/flake#desktop

    extra-substituters = [
      "https://zed.cachix.org"
      "https://hyprland.cachix.org"
      "https://nix-community.cachix.org"
      "https://yazi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];

    trusted-users = [
      "jadee"
    ];
  };

  environment.variables = {
    CARGO_BUILD_JOBS = "2";
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };
}
