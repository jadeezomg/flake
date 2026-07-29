# Nix daemon config for Darwin.
#
# Determinate Nix owns /etc/nix/nix.conf, so nix-darwin's `nix.settings` (set in
# modules/shared/environment.nix) is silently inert here — that is why builds on
# caya missed cache.numtide.com and rebuilt every llm-agents package from
# source. Determinate's own nix-darwin module writes /etc/nix/nix.custom.conf,
# which nix.conf `!include`s, so this is the one channel that lands.
#
# The caches are declared here rather than left to the flake's `nixConfig`:
# flake-supplied settings are ignored for untrusted users and only *prompted*
# for trusted ones, which never resolves inside `nh`/`just`.
{
  lib,
  dotfilesLib,
  user,
  ...
}:
let
  darwinCaches = lib.filter (c: c.darwin) dotfilesLib.nixCaches;
in
{
  determinateNix.customSettings = {
    extra-substituters = map (c: c.url) darwinCaches;
    extra-trusted-public-keys = map (c: c.key) darwinCaches;

    # Needed for `nix build`/`nix develop` on flakes that carry their own
    # substituters, and for signing-key overrides when pulling from a builder.
    trusted-users = [
      "root"
      user
    ];
  };
}
