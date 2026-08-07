{
  config,
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

    # Homebrew >= 6.0 refuses to load formulae and casks from untrusted
    # third-party taps. `brew bundle` trusts the entries in its own Brewfile
    # (nix-darwin's `trusted: true`) but only persists that trust as it goes, so
    # the `brew cleanup` in the same activation can still abort with "Refusing to
    # load cask nkzw-tech/tap/codiff from untrusted tap nkzw-tech/tap".
    # nix-homebrew runs `brew trust` during the Homebrew setup phase, before the
    # bundle step, which makes a fresh install deterministic instead of needing a
    # second switch.
    trust.taps = [ "nkzw-tech/tap" ]; # codiff

    # One trust store for every brew invocation. This is baked into the brew
    # wrapper, so it covers activation — which drops XDG_CONFIG_HOME, since
    # nix-darwin runs brew under `sudo --set-home env …` — as well as interactive
    # shells. Without it the two contexts use ~/.homebrew/trust.json and
    # ~/.config/homebrew/trust.json respectively, and trust granted in one is
    # invisible in the other.
    extraEnv.XDG_CONFIG_HOME = "${config.users.users.${user}.home}/.config";

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
