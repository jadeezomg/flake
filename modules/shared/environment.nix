{
  dotfilesLib,
  config,
  pkgs,
  host ? { },
  lib,
  ...
}:
let
  buildCores = host.buildCores or 6;
  isDarwin = lib.hasSuffix "-darwin" (host.system or "");
  nixExperimentalFeatures = dotfilesLib.nixExperimentalFeatures {
    inherit lib;
    inherit isDarwin;
  };
in
{
  nix.settings = {
    auto-optimise-store = true;
    download-buffer-size = 524288000; # 500 MiB
    max-jobs = 1;
    cores = buildCores;

    # Cache list lives in lib/nix-caches.nix — Darwin can't reuse `nix.settings`
    # (Determinate owns nix.conf), so it reads the same data from
    # modules/darwin/nix.nix.
    extra-substituters = map (c: c.url) dotfilesLib.nixCaches;
    extra-trusted-public-keys = map (c: c.key) dotfilesLib.nixCaches;
    # CA / dynamic derivations (Linux only). Not enabled on
    # Darwin (Determinate / unused). NixOS applies these after `switch`; the
    # *evaluating* client also needs them — see `lib/nix-experimental-features.nix`
    # and Home Manager `nix.settings` on Linux.
    experimental-features = nixExperimentalFeatures;

    trusted-users = [
      "jadee"
    ];
  }
  // lib.optionalAttrs isDarwin {
    # nix-darwin Homebrew generates a Brewfile derivation that references
    # /bin/sh; Darwin sandbox rejects it unless these host prefixes are allowed.
    allowed-impure-host-deps = [
      "/bin/sh"
      "/bin/bash"
      "/usr/bin/env"
    ];
    extra-sandbox-paths = [
      "/bin/sh"
      "/bin/bash"
      "/usr/bin/env"
    ];
  };

  environment.variables = {
    CARGO_BUILD_JOBS = toString (lib.max 1 (buildCores / 2));
    CARGO_NET_GIT_FETCH_WITH_CLI = "true";
  };

  # Generate a list of installed system packages for easy inspection
  # (cat /etc/current-system-packages).
  environment.etc."current-system-packages".text =
    let
      packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
      sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
    in
    builtins.concatStringsSep "\n" sortedUnique;
}
