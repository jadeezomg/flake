# Self-expiring workaround guards. See the `overlays` skill for usage rules.
#
# A workaround exists because of some upstream state that will eventually change:
# nixpkgs ships the newer version, un-marks the package broken, adopts the patch,
# fixes the module. Nothing normally tells us when that happens, so workarounds
# outlive their justification and quietly rot in the tree.
#
# These combinators make a workaround carry its own justification as an eval-time
# condition and print a warning the moment the condition flips, so `flake update`
# reports what it made redundant instead of us finding out years later.
#
# Consumed by overlays (bound per file in parts/overlays/default.nix) and by
# modules through `dotfilesLib.expiry "<repo-relative path>"`.
#
# Conditions must be evaluable offline. Nix cannot ask whether an upstream issue
# is closed, so guard on something in the pinned tree that the fix would change —
# a version, an attribute, a patch marker — and put the issue URL in `reason` for
# whoever reads the warning.
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
# Repo-relative path of the file owning the workaround, so the warning says what
# to go edit: "parts/overlays/foo-fix.nix", "hosts/mini/default.nix", …
location: {
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
      Drop the workaround; delete the file once nothing else in it is live.
    '' (if fixed then fallback else workaround);

  # For a condition that only *suggests* staleness — upstream test skips, build
  # sandbox workarounds, module-level fixes for a still-open upstream bug,
  # anything whose justification cannot be expressed exactly. Keeps applying the
  # workaround (dropping it on a guess would break the build) and nags us to
  # re-verify it by hand.
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
      Re-verify the workaround, then move its threshold forward or delete it.
    '' workaround;
}
