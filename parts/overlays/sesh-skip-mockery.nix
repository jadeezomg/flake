# sesh runs `mockery` in preBuild with a mockery built by Go 1.27. mockery 3.8.0
# vendors a golang.org/x/tools that cannot read Go 1.27 export data ("export
# data version 5 is greater than maximum supported version 4"), so both the
# mockery checks and the sesh preBuild fail. Hydra has no sesh build either.
#
# The generated mocks are gitignored mock_*.go files that only the sesh tests
# use. Skip mockery and the Go tests; keep the version install check.
# Related nixpkgs PR: https://github.com/NixOS/nixpkgs/pull/565040
#
# Verified 2026-10-11 against sesh 2.32.0 and go-mockery 3.8.0.
{
  expiry,
  lib,
}:
_final: prev: {
  sesh =
    expiry.recheckWhen
      {
        stale =
          lib.versionAtLeast prev.go-mockery.version "3.9" || lib.versionAtLeast prev.sesh.version "2.34";
        reason = "go-mockery reached 3.9 or sesh reached 2.34 (skip verified needed at mockery 3.8.0, sesh 2.32.0); check whether nixpkgs sesh builds again (nix path-info --store https://cache.nixos.org on its outPath) and drop the overlay if it does.";
      }
      (
        prev.sesh.overrideAttrs (old: {
          nativeBuildInputs = lib.filter (p: (p.pname or "") != "go-mockery") old.nativeBuildInputs;
          preBuild = "";
          doCheck = false;
        })
      );
}
