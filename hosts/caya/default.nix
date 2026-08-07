{
  inputs,
  lib,
  user,
  dotfilesLib,
  ...
}:
let
  # brew version nix-homebrew pins, read from its own lock the same way its
  # module derives `version`.
  upstreamBrew =
    (builtins.fromJSON (builtins.readFile "${inputs.nix-homebrew}/flake.lock"))
    .nodes.brew-src.original.ref;
in
{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/profiles
    ./profiles.nix
  ];

  nix-homebrew = {
    inherit user;
    enable = true;

    # The homebrew-core and homebrew-cask taps are tracked at HEAD, so their
    # formulae and casks use DSL that only newer brew understands, and nothing
    # falls back to the API (nix-homebrew taps have no git repo). Two known
    # breakages, both fatal during activation:
    #   - casks: `command_wrapper` artifact needs brew >= 6.0.13
    #     (Homebrew/brew#23308) — "Cask 'firefox' definition is invalid:
    #     undefined method 'command_wrapper'".
    #   - formulae: `configure_clang_system` install step needs brew >= 6.0.14 —
    #     "homebrew/core/llvm: undefined local variable or method
    #     'configure_clang_system'", which fails every `brew upgrade`.
    # Point it at a newer brew until nix-homebrew catches up. The guard covers
    # the higher of the two thresholds; nix-homebrew reaching only 6.0.13 once
    # retired this override while the formula DSL still needed 6.0.14.
    package =
      (dotfilesLib.expiry { inherit lib; } "hosts/caya/default.nix").expireWhen
        {
          fixed = lib.versionAtLeast upstreamBrew "6.0.15";
          reason = "nix-homebrew now pins brew ${upstreamBrew}, which understands the cask command_wrapper and formula configure_clang_system DSL.";
          # Nothing to define — nix-homebrew's own default is what we want back.
          fallback = lib.mkIf false null;
        }
        (
          inputs.brew-src
          // {
            name = "brew-6.0.15";
            version = "6.0.15";
          }
        );

    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
      "nkzw-tech/homebrew-tap" = inputs.homebrew-nkzw-tap;
    };
    mutableTaps = true;
    autoMigrate = true;
  };

  system.stateVersion = "26.05";
}
