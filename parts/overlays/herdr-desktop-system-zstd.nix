# herdr-desktop's ghostty zstd-sys dependency is configured to use the system
# libzstd, but the derivation never put `zstd` in buildInputs, so the build
# stops in zstd-sys' build script:
#
#   The system library `libzstd` required by crate `zstd-sys` was not found.
#   The file `libzstd.pc` needs to be installed and the PKG_CONFIG_PATH
#   environment variable must contain its parent directory.
#
# Upstream fixed it in NixOS/nixpkgs@2d02af8e2df9 ("herdr-desktop: fix build
# with system libs", 2026-11-07) by making zstd an unconditional build input.
# That commit is on master but not in our nixos-unstable pin, so this mirrors
# just the zstd half (pkg-config is already a native input on Linux).
#
# Verified 2026-11-11 against herdr-desktop 0.1.10 on nixos-unstable f9a75f4.
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
    herdr-desktop =
      expiry.expireWhen
        {
          fixed = lib.elem "zstd" (map (d: d.pname or "") prev.herdr-desktop.buildInputs);
          reason = "nixpkgs now puts zstd in herdr-desktop's buildInputs (NixOS/nixpkgs@2d02af8e2df9).";
          fallback = prev.herdr-desktop;
        }
        (
          prev.herdr-desktop.overrideAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd ];
          })
        );
  }
