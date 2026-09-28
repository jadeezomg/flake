# cargo-generate fails one unit test on darwin in the nix sandbox. The test
# asserts that a canonicalized relative path starts with "/Users/", but the
# sandbox builds under /private/tmp:
#   thread 'utils::tests::should_canonicalize' panicked at src/utils.rs:72:13:
#   assertion failed: canonicalize_path(PathBuf::from("../")).unwrap()
#                       .starts_with("/Users/")
# nixpkgs already skips this test, but under its old name
# `git::utils::should_canonicalize`. Upstream moved it to
# `utils::tests::should_canonicalize`, so the skip no longer matches. This
# overlay adds the current name. The x86_64-linux build of the same version is
# in cache.nixos.org, which means the fault is darwin-only.
#
# Verified 2026-09-28 against cargo-generate 0.25.0 on aarch64-darwin.
{
  expiry,
  lib,
  system,
}:
let
  isDarwin = builtins.match ".*-darwin" system != null;
  skip = "--skip=utils::tests::should_canonicalize";
in
_final: prev:
if !isDarwin then
  { }
else
  {
    cargo-generate =
      expiry.expireWhen
        {
          fixed = lib.elem skip (prev.cargo-generate.checkFlags or [ ]);
          reason = "nixpkgs now skips utils::tests::should_canonicalize itself.";
          fallback = prev.cargo-generate;
        }
        (
          prev.cargo-generate.overrideAttrs (old: {
            checkFlags = (old.checkFlags or [ ]) ++ [ skip ];
          })
        );
  }
