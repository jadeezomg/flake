{
  config,
  dotfilesLib,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:
let
  # homebrew-cask uses `zap :not_required` since 2026-10-27 (font-sf-mono,
  # font-sf-pro). Homebrew reads it from 7.0.11 on, but nix-homebrew pins 7.0.4,
  # so `brew bundle` failed on those casks. nix-homebrew patches this package
  # the same way as its own pin.
  brewVersion = "7.0.11";
  nixHomebrewBrewVersion =
    (lib.importJSON "${inputs.nix-homebrew}/flake.lock").nodes.brew-src.original.ref;
  newerBrew = (dotfilesLib.expiry { inherit lib; } "hosts/caya/default.nix").expireWhen {
    fixed = lib.versionAtLeast nixHomebrewBrewVersion brewVersion;
    reason = "nix-homebrew now pins Homebrew ${nixHomebrewBrewVersion}. Delete newerBrew and the nix-homebrew.package override.";
    fallback = false;
  } true;
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

    package = lib.mkIf newerBrew (
      pkgs.fetchFromGitHub {
        owner = "Homebrew";
        repo = "brew";
        tag = brewVersion;
        hash = "sha256-8mCor0DDjNhi+0e+FllfqiMABujBl+/RxYW+wgMpcto=";
      }
      // {
        name = "brew-${brewVersion}";
        version = brewVersion;
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
}
