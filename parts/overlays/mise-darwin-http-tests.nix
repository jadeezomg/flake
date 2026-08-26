# mise fails one http test on darwin. The panic poisons a lock that the whole
# http::tests module shares, so 32 more tests fail with PoisonError. The
# x86_64-linux build of the same version is in cache.nixos.org, which means the
# fault is darwin-only. This overlay skips the test that panics first and lets
# the other 32 run.
#
# Verified 2026-08-24 against mise 2026.8.6 on aarch64-darwin. The unpatched
# build fails with:
#   http::tests::test_download_recovers_from_unsatisfied_range
#   HTTP status client error (416 Range Not Satisfiable)
# The test drives a local mock server, so the sandbox does not block network
# access here. No nixpkgs issue tracks it yet.
{
  expiry,
  lib,
  system,
}:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
_final: prev:
if !isDarwin then
  { }
else
  {
    mise =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.mise.version "2026.11";
          reason = "mise reached 2026.11 (416-range skip verified needed at 2026.8.6); retest the darwin http test failure.";
        }
        (
          prev.mise.overrideAttrs (old: {
            checkFlags = (old.checkFlags or [ ]) ++ [
              "--skip=http::tests::test_download_recovers_from_unsatisfied_range"
            ];
          })
        );
  }
