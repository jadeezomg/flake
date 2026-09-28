# Node.js 26.9.0 ships test-fs-cp-async-file-modes, which chmods a file with
# the setuid bit. The Nix build sandbox forbids that and returns EPERM, so the
# check phase fails and podman-desktop (nodejs-slim_26) cannot build. nixpkgs
# skips sandbox-hostile tests through CI_SKIP_TESTS in checkFlags but has not
# added this one yet. This overlay appends it to that list.
#
# Verified 2026-09-19 against nodejs-slim 26.9.0 on x86_64-linux (nixpkgs
# e554fab). The unpatched build fails with:
#   Error: EPERM: operation not permitted, chmod '.../copy_%1/suid'
{
  expiry,
  lib,
}:
_final: prev:
let
  test = "test-fs-cp-async-file-modes";
in
{
  nodejs-slim_26 =
    expiry.expireWhen
      {
        fixed = lib.any (lib.hasInfix test) prev.nodejs-slim_26.checkFlags;
        reason = "nixpkgs now skips ${test} itself.";
        fallback = prev.nodejs-slim_26;
      }
      (
        prev.nodejs-slim_26.overrideAttrs (old: {
          checkFlags = map (
            flag: if lib.hasPrefix "CI_SKIP_TESTS=" flag then "${flag},${test}" else flag
          ) old.checkFlags;
        })
      );
}
