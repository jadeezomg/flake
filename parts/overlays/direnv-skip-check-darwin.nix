# direnv's upstream test suite (esp. zsh) can hang or run far too long under
# the macOS Nix sandbox, blocking the whole system/home closure. Skipping check
# only on Darwin; Linux nixpkgs/Hydra paths keep running tests.
#
# No exact expiry condition — "the sandbox no longer hangs" is not observable at
# eval time. Nag on a future minor instead; last verified needed at 2.37.1.
{
  expiry,
  lib,
  system,
}:
_final: prev:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
if !isDarwin then
  { }
else
  {
    direnv =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.direnv.version "2.40";
          reason = "direnv reached 2.40 (skip verified needed at 2.37.1); retest whether its checkPhase still hangs in the Darwin sandbox.";
        }
        (
          prev.direnv.overrideAttrs (_old: {
            doCheck = false;
          })
        );
  }
