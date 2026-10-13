# typescript-language-server 6.0.2 shipped with a wrong pnpmDeps hash, so the
# fixed-output fetch fails with a hash mismatch. nixpkgs master fixed it in
# ac7b1aaed0 ("typescript-language-server: fix pnpm hash"), but the fix was not
# in nixos-unstable on 2026-10-14. Set the corrected hash until it lands.
#
# Verified 2026-10-14 against nixos-unstable 7fd4004.
{
  expiry,
}:
let
  fixedHash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
in
_final: prev: {
  typescript-language-server =
    expiry.expireWhen
      {
        fixed =
          prev.typescript-language-server.version != "6.0.2"
          || prev.typescript-language-server.pnpmDeps.outputHash == fixedHash;
        reason = "nixpkgs typescript-language-server is no longer 6.0.2 with the broken pnpmDeps hash (fixed upstream in ac7b1aaed0).";
        fallback = prev.typescript-language-server;
      }
      (
        prev.typescript-language-server.overrideAttrs (old: {
          pnpmDeps = old.pnpmDeps.overrideAttrs { outputHash = fixedHash; };
        })
      );
}
