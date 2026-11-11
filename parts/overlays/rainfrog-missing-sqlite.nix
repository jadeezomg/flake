# rainfrog links sqlx-sqlite against the system libsqlite3, but its nixpkgs
# derivation only lists libgit2, so the build stops at
#
#   ld.bfd: cannot find -lsqlite3: No such file or directory
#
# Upstream fixed it in NixOS/nixpkgs@c193279cb2e1 ("rainfrog: add sqlite to
# build inputs", 2026-11-08), which is on master but not in our pin.
#
# Verified 2026-11-11 against rainfrog 0.4.6 on nixos-unstable f9a75f4.
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
    rainfrog =
      expiry.expireWhen
        {
          fixed = lib.elem "sqlite" (map (d: d.pname or "") prev.rainfrog.buildInputs);
          reason = "nixpkgs now puts sqlite in rainfrog's buildInputs (NixOS/nixpkgs@c193279cb2e1).";
          fallback = prev.rainfrog;
        }
        (
          prev.rainfrog.overrideAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.sqlite ];
          })
        );
  }
