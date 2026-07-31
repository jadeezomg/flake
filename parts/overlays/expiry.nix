# Self-expiring overlay guards. See the `overlays` skill for usage rules.
#
# A workaround overlay exists for a reason that will eventually stop being true:
# nixpkgs ships the newer version, un-marks the package broken, adopts the patch
# upstream. Nothing normally tells us when that happens, so workarounds outlive
# their justification and quietly rot in the tree.
#
# These combinators make the overlay carry its own justification as an
# eval-time condition, and print a warning the moment the condition flips.
# `flake update` then reports which overlays it made redundant, instead of us
# finding out years later.
#
# HAZARD: guard attribute *values*, never the attrset an overlay returns.
# Nixpkgs must know an overlay's attribute names before it can evaluate the
# final package set; a guard around the attrset forces its condition during that
# step, and any condition that reads `prev.<drv>` then loops back through
# `final` — infinite recursion. Inside a value, the condition is only forced
# once someone asks for that package, which is safe.
#
# Pattern from
# https://jezenthomas.com/2026/07/nix-overrides-that-expire-themselves/
{ lib }:
# Bound to the overlay's own file name at the import site in ./default.nix, so
# the warning says which file to delete.
overlay:
let
  location = "parts/overlays/${overlay}.nix";
in
{
  # For a condition that *is* the justification: when it flips, the workaround
  # is provably redundant, so stop applying it and say so.
  #
  #   foo = expireWhen {
  #     fixed = lib.versionAtLeast prev.foo.version "1.2";
  #     reason = "nixpkgs now ships foo >= 1.2.";
  #     fallback = prev.foo;
  #   } (prev.foo.overrideAttrs …);
  #
  # `fallback` is nearly always the untouched `prev` package: once the condition
  # holds, upstream is what we wanted all along.
  expireWhen =
    {
      fixed,
      reason,
      fallback,
    }:
    workaround:
    lib.warnIf fixed ''
      ${location} is obsolete: ${reason}
      Drop the override; delete the file once nothing else in it is live.
    '' (if fixed then fallback else workaround);

  # For a condition that only *suggests* staleness — upstream test skips, build
  # sandbox workarounds, anything whose justification cannot be expressed
  # exactly. Keeps applying the workaround (dropping it on a guess would break
  # the build) and nags us to re-verify it by hand.
  #
  #   foo = recheckWhen {
  #     stale = lib.versionAtLeast prev.foo.version "1.5";
  #     reason = "foo reached 1.5; retest whether the sandbox hang is fixed.";
  #   } (prev.foo.overrideAttrs …);
  #
  # Pick a threshold a few releases out, not the next patch bump — this fires on
  # every eval until someone acts on it, so per-release nagging is just noise.
  recheckWhen =
    { stale, reason }:
    workaround:
    lib.warnIf stale ''
      ${location} needs re-checking: ${reason}
      Re-verify the workaround, then move its threshold forward or delete the file.
    '' workaround;
}
