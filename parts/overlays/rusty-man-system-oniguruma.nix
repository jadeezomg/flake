# rusty-man's onig_sys sets RUSTONIG_SYSTEM_LIBONIG, so it wants the system
# oniguruma through pkg-config. The nixpkgs derivation lists neither, and the
# build panics in onig_sys-69.7.0/build.rs:255:
#
#   Unable to find oniguruma in pkg-config, and RUSTONIG_SYSTEM_LIBONIG is set:
#   Failed to run `pkg-config --libs --cflags oniguruma`: No such file or
#   directory (os error 2)
#
# Upstream fixed it in NixOS/nixpkgs@492f34b4a3e0 ("rusty-man: fix build with
# sys libs, modernize", 2026-11-08): pkg-config as a native input, oniguruma as
# a build input. Master-only for now.
#
# Verified 2026-11-11 against rusty-man 0.5.0 on nixos-unstable f9a75f4.
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
    rusty-man =
      expiry.expireWhen
        {
          fixed = lib.elem "oniguruma" (map (d: d.pname or "") prev.rusty-man.buildInputs);
          reason = "nixpkgs now gives rusty-man pkg-config and oniguruma itself (NixOS/nixpkgs@492f34b4a3e0).";
          fallback = prev.rusty-man;
        }
        (
          prev.rusty-man.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.oniguruma ];
          })
        );
  }
