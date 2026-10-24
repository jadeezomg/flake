# CoreCycler: per-core stability tester and PBO Curve Optimizer tuner for the
# desktop 7800X3D. Re-enabled 2026-09-02.
#
# The earlier local zenpower5 build (hosts/desktop/zenpower5.nix) worked around
# a corecycler heuristic that forced clang on any kernel with "cachyos" in its
# name. Upstream now detects LLVM from the kernel makeFlags (nix/zenpower.nix,
# nix/ryzen-smu.nix), so the bundled modules are used again.
#
# The kernel modules build against the CachyOS kernel and are not in any binary
# cache. Expect a local build on the first switch and on every kernel bump.
#
# Module certificates: since NixOS/nixpkgs#571181 the kernel signs each module
# with kmodigest during Kbuild `modules_install`, and aggregateModules needs a
# <module>.ko.cer next to every external module (NixOS/nixpkgs#575192).
# corecycler's zenpower and ryzen_smu copy the .ko by hand, so they have no
# .cer and the -modules build fails. The override below signs them after the
# fixup phase (strip would drop an earlier signature). It swaps them into
# system.modulesTree, because the corecycler module gives no package option.
# Verified 2026-10-24 against corecycler afa8208 and kernel 7.3.0-cachyos.
{
  config,
  dotfilesLib,
  inputs,
  lib,
  pkgs,
  user,
  ...
}:
let
  inherit (config.boot.kernelPackages) kernel;

  needsCertificate =
    pkg:
    let
      name = lib.getName pkg;
    in
    name == "zenpower" || lib.hasPrefix "ryzen-smu" name;

  withCertificate =
    pkg:
    (dotfilesLib.expiry { inherit lib; } "hosts/desktop/corecycler.nix").expireWhen
      {
        fixed = !(lib.hasInfix ".ko" (pkg.installPhase or ""));
        reason = "corecycler's ${lib.getName pkg} no longer copies the .ko by hand, so it now installs through modules_install and gets its .ko.cer. Drop withCertificate and the system.modulesTree override.";
        fallback = pkg;
      }
      (
        pkg.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.buildPackages.kmodigest ];
          postFixup = (old.postFixup or "") + ''
            find "$out/lib/modules" -name '*.ko' -exec kmodigest {} \;
          '';
        })
      );
in
{
  imports = [ inputs.corecycler.nixosModules.default ];

  services.corecycler = {
    enable = true;
    unfreeBackends = true; # mprime is the best backend for CO tuning.
    deviceAccessUser = user;
    ryzenSmu = true; # Curve Optimizer read/write over the SMU mailbox.
    zenpower = true; # Replaces k10temp; the module blacklists it.
    nct6775 = true; # Nuvoton Super I/O: Vcore, fans, board temps.
    spd5118 = true; # DDR5 DIMM temperatures.
  };

  # Same list as nixos/modules/system/boot/kernel.nix, with the signed modules.
  system.modulesTree = lib.mkForce (
    [ (lib.getOutput "modules" kernel) ]
    ++ map (
      pkg: if needsCertificate pkg then withCertificate pkg else pkg
    ) config.boot.extraModulePackages
  );
}
