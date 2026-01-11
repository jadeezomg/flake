{
  config,
  pkgs,
  lib,
  ...
}: let
  numCores = config.nixpkgs.hostPlatform.numCores or 8;
  buildCores = lib.max 1 (numCores - 6);
  buildJobs = buildCores;
in {
  nix.settings = {
    download-buffer-size = 524288000; # 500 MiB
    max-jobs = buildJobs;
    cores = buildCores;
    # Add zed-editor binary caches to avoid building from source
    # See: https://github.com/zed-industries/zed/blob/main/flake.nix
    extra-substituters = [
      "https://zed.cachix.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    # Nix experimental features
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };

  environment.variables = {
    CARGO_BUILD_JOBS = toString buildCores;
    RUSTC_JOBS = toString buildCores;
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };
}
