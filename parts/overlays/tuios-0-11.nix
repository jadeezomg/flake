# tuios 0.11.0. nixpkgs ships 0.10.1, which has GHSA-78rj-pghh-vh42: in one
# session, a pane can answer the permission prompt of an agent in another pane.
# 0.11.0 fixes it. The herdr/tuios trial (D2 in
# docs/agents/session-management-plan.md) runs agents in tuios, so it must not
# use 0.10.1.
#
# 0.11.0 builds as a Go workspace: go.work joins the app and the Go libraries
# in the repo (progstatus/ and others). nixpkgs builds 0.10.1 with GOWORK=off.
# The steps below follow upstream's tuios.nix at v0.11.0: drop the e2e module
# from the workspace, and vendor with `go work vendor`. buildGoModule takes the
# module build phase from its original arguments, so it goes in through
# passthru.overrideModAttrs.
#
# caya takes tuios from Homebrew instead (modules/profiles/devenv/agents/darwin.nix).
# When this overlay retires, move caya back to the Nix package there.
#
# Verified 2026-10-26 against nixpkgs tuios 0.10.1.
{
  expiry,
  lib,
}:
_final: prev: {
  tuios =
    expiry.expireWhen
      {
        fixed = lib.versionAtLeast prev.tuios.version "0.11.0";
        reason = "nixpkgs now ships tuios >= 0.11.0 (fix for GHSA-78rj-pghh-vh42).";
        fallback = prev.tuios;
      }
      (
        prev.tuios.overrideAttrs (
          finalAttrs: old: {
            version = "0.11.0";
            src = prev.fetchFromGitHub {
              owner = "Gaurav-Gosain";
              repo = "tuios";
              tag = "v${finalAttrs.version}";
              hash = "sha256-Ss8jYuaCkivmAzbwnlPciOtR9ftsy7wAg/mNxm/WsK0=";
            };
            vendorHash = "sha256-oJDNhlkyM95PkMc0AM8Owu1ybGEHZyFfpVRN8i6CK48=";
            env = removeAttrs old.env [ "GOWORK" ];
            postPatch = (old.postPatch or "") + ''
              go work edit -dropuse=./e2e/tui
            '';
            # Some cmd/tuios tests call git to check branch names.
            nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ prev.git ];
            passthru = old.passthru // {
              overrideModAttrs = lib.composeExtensions old.passthru.overrideModAttrs (
                _: _: {
                  buildPhase = ''
                    runHook preBuild
                    go work vendor
                    runHook postBuild
                  '';
                }
              );
            };
          }
        )
      );
}
