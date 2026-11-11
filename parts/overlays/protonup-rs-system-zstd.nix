# protonup-rs 0.15.1's zstd-sys builds against the system libzstd, but the
# nixpkgs derivation lists neither the library nor pkg-config, so its build
# script dies:
#
#   Can't probe for zstd in pkg-config: Could not run `pkg-config --static
#   --libs --cflags libzstd`
#   The pkg-config command could not be found.
#
# Upstream fixed it in NixOS/nixpkgs@ca5fa5186579 ("protonup-rs: use system
# aws-lc, zstd", 2026-11-10) by adding pkg-config, zstd and aws-lc; both
# libraries exist in our pin, so this mirrors that change exactly.
#
# Verified 2026-11-11 against protonup-rs 0.15.1 on nixos-unstable f9a75f4.
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
    protonup-rs =
      expiry.expireWhen
        {
          fixed = lib.elem "pkg-config" (map (d: d.pname or "") prev.protonup-rs.nativeBuildInputs);
          reason = "nixpkgs now gives protonup-rs pkg-config and zstd itself (NixOS/nixpkgs@ca5fa5186579).";
          fallback = prev.protonup-rs;
        }
        (
          prev.protonup-rs.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
            buildInputs = (old.buildInputs or [ ]) ++ [
              prev.aws-lc
              prev.zstd
            ];
          })
        );
  }
