# lact and niri vendor libdisplay-info-sys, which requires libdisplay-info < 0.4.0.
# Our nixpkgs rev ships libdisplay-info 0.4.0; upstream nixpkgs fixed this by
# pinning libdisplay-info_0_3 in affected buildInputs (NixOS/nixpkgs#546155).
# Mirror that until we pick up the fix via nixpkgs bump.
{ lib, system }:
final: prev:
let
  isLinux = builtins.match ".*-linux" system != null;

  libdisplay-info_0_3 = prev.libdisplay-info.overrideAttrs (_old: {
    version = "0.3.0";
    src = prev.fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "emersion";
      repo = "libdisplay-info";
      rev = "0.3.0";
      hash = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
    };
  });

  withLibdisplayInfo03 =
    pkg:
    pkg.overrideAttrs (oldAttrs: {
      buildInputs = lib.subtractLists [ prev.libdisplay-info ] oldAttrs.buildInputs ++ [
        libdisplay-info_0_3
      ];
    });
in
if !isLinux then
  { }
else
  {
    inherit libdisplay-info_0_3;
    lact = withLibdisplayInfo03 prev.lact;
    niri = withLibdisplayInfo03 prev.niri;
  }
