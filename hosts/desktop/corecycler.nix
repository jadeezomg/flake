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
{ inputs, user, ... }:
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
}
