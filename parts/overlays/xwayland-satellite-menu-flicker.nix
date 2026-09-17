# xwayland-satellite 0.8.2 breaks X11 popup menus under niri: drop-down and
# context menus flicker or close at once (Steam, wine apps). 0.8.1 does not
# have the bug. This overlay pins the package back to 0.8.1.
#
# Verified 2026-09-14 against xwayland-satellite 0.8.2 in nixpkgs.
# Upstream issue: https://github.com/Supreeeme/xwayland-satellite/issues/468
{
  expiry,
  lib,
  system,
}:
let
  isLinux = builtins.match ".*-linux" system != null;
in
final: prev:
if !isLinux then
  { }
else
  {
    xwayland-satellite =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.xwayland-satellite.version "0.8.3";
          reason = "xwayland-satellite reached 0.8.3 (pin to 0.8.1 verified needed at 0.8.2); retest X11 popup menus under niri and drop the pin if fixed.";
        }
        (
          prev.xwayland-satellite.overrideAttrs (
            old:
            let
              version = "0.8.1";
              src = final.fetchFromGitHub {
                owner = "Supreeeme";
                repo = "xwayland-satellite";
                tag = "v${version}";
                hash = "sha256-BUE41HjLIGPjq3U8VXPjf8asH8GaMI7FYdgrIHKFMXA=";
              };
            in
            {
              inherit version src;
              cargoDeps = final.rustPlatform.fetchCargoVendor {
                inherit (old) pname;
                inherit version src;
                hash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
              };
            }
          )
        );
  }
