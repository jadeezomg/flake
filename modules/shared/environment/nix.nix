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
    extra-substituters = [
      "https://zed.cachix.org"
      "https://cache.garnix.io"
      "https://hyprland.cachix.org"
      "https://nix-community.cachix.org"
      "https://yazi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "hyprland.cachix.org-1:a7pgxzMz7+7nJIFm9H7wLd50sLtCWfKuvIdxb7VKCNc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUY8+c1RzM5L2l7Vq0v8J5Y8K8k="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kjtQxdHS3zbl2CCC8mY="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };

  environment.variables = {
    CARGO_BUILD_JOBS = "2";
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };
}
