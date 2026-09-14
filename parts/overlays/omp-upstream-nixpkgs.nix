# omp built through llm-agents.overlays.shared-nixpkgs fails its smoke test on
# our nixpkgs: the compiled bun binary reads zeros from its embedded bunfs
# ("SyntaxError: Invalid character: \0 at /$bunfs/root/prelude-*.txt").
# The same recipe built against llm-agents' own pinned nixpkgs passes and is in
# cache.numtide.com, so the fault is in our toolchain (rustc 1.98 vs 1.97,
# different stdenv), not in the package. Take omp from the flake's own package
# set until then: cached, no six-minute local build.
#
# Verified 2026-09-14 against omp 18.1.19, llm-agents 9dd4d34, nixpkgs eaad089.
# Upstream tracks the bun-template workaround in
# https://github.com/numtide/llm-agents.nix/issues/7841; once that lands the
# shared-nixpkgs build may work again.
{
  expiry,
  inputs,
  lib,
  system,
}:
_final: prev: {
  llm-agents = prev.llm-agents // {
    omp = expiry.recheckWhen {
      stale = lib.versionAtLeast prev.llm-agents.omp.version "18.4";
      reason = "omp reached 18.4 (shared-nixpkgs smoke test failure verified at 18.1.19); retest building omp through shared-nixpkgs.";
    } inputs.llm-agents.packages.${system}.omp;
  };
}
