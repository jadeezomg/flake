{
  config,
  inputs,
  user,
  ...
}:
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
