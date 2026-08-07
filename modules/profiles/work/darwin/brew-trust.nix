# Homebrew >= 6.0 enables HOMEBREW_REQUIRE_TAP_TRUST, which refuses to load
# formulae and casks from third-party taps that are not in brew's trust store.
# The `trusted: true` Brewfile flag (nix-darwin's `homebrew.casks.*.trusted`)
# only covers `brew bundle` itself — the `brew cleanup` that
# `homebrew.onActivation.cleanup` triggers reads the trust store instead and
# aborts activation with
# "Refusing to load cask nkzw-tech/tap/codiff from untrusted tap nkzw-tech/tap".
# Declaring the trust here (rather than running `brew trust` once by hand) keeps
# a fresh caya install working.
#
# Path: brew reads `$XDG_CONFIG_HOME/homebrew/trust.json`, falling back to
# `~/.homebrew/trust.json` when XDG_CONFIG_HOME is unset — which is the case
# during activation, since nix-darwin runs brew through
# `sudo --user=… --set-home env …`. `homebrew.onActivation.extraEnv` in
# ./default.nix pins XDG_CONFIG_HOME so activation and an interactive shell
# read this same file.
#
# Trusted tap names use brew's short form (`<user>/tap`, not
# `<user>/homebrew-tap`) — the long form is not recognised.
#
# This file is a Nix store symlink, so `brew trust` and `brew untrust` refuse to
# write through it ("Refusing to write insecure trust store"). Edit the list
# below instead; the flake is the only source of truth for tap trust.
{ ... }:
{
  xdg.configFile."homebrew/trust.json".text = builtins.toJSON {
    trustedtaps = [
      "nkzw-tech/tap" # codiff (see ../default.nix casks)
    ];
  };
}
