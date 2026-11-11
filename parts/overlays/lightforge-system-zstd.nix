# Lightforge's own Nix derivation (packaging/nix/package.nix in the upstream
# flake) gives the build only `udev`, but its zstd dependency probes the system
# library through pkg-config, so the build stops in zstd-sys' build script:
#
#   Can't probe for zstd in pkg-config:
#   Package libzstd was not found in the pkg-config search path.
#   The system library `libzstd` required by crate `zstd-sys` was not found.
#
# Upstream has not fixed this as of v1.0.0-beta.11, so the fix lives here
# rather than in a channel bump: zstd's dev output provides libzstd.pc.
#
# This overlay must stay ordered after `inputs.lightforge.overlays.default` in
# parts/overlays/default.nix: it overrides the attribute that overlay defines.
# `lightforge`'s steam-run-free wrapper resolves `lightforge-unwrapped` through
# `final`, so it picks the patched build up without being repeated here.
#
# Verified 2026-11-11 against lightforge 1.0.0-beta.11.
{
  expiry,
  lib,
  system,
}:
let
  isLinux = lib.hasInfix "-linux" system;
in
_final: prev:
if !isLinux then
  { }
else
  {
    lightforge-unwrapped =
      expiry.expireWhen
        {
          fixed = lib.elem "zstd" (map (d: d.pname or "") prev.lightforge-unwrapped.buildInputs);
          reason = "upstream lightforge's packaging now puts zstd in buildInputs; bump the flake input and delete this file.";
          fallback = prev.lightforge-unwrapped;
        }
        (
          prev.lightforge-unwrapped.overrideAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd ];
          })
        );
  }
