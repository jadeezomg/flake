# Lists for `nix.settings.experimental-features` (NixOS + Home Manager user client).
# HM's ~/.config/nix/nix.conf is read by the `nix` / `nh` client before switch, so Linux
# users need CA here when evaluating closures that use ca-derivations.
{
  lib,
  isDarwin,
}:
[
  "nix-command"
  "flakes"
  "pipe-operators"
]
++ lib.optionals (!isDarwin) [
  "ca-derivations"
  "dynamic-derivations"
]
