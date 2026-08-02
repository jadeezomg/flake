# Take omp from llm-agents' own package set instead of `overlays.shared-nixpkgs`.
#
# Not a workaround overlay, so no expiry guard — this is a standing decision
# about which nixpkgs omp builds against, not a bug being waited out.
#
# omp is a bun2nix package: its dependency set materializes as one
# fixed-output derivation per npm tarball, ~610 of them. `shared-nixpkgs`
# builds against the *consumer's* nixpkgs (upstream's own comment: "the binary
# cache only hits when the consumer's nixpkgs revision matches ours"), and
# numtide only pushes builds against their pinned rev. Result: every rebuild
# missed cache.numtide.com, refetched all 610 tarballs from npm, and buried
# the nom tree — each FOD is a root there until `bun-cache` starts, which it
# cannot until every one of them finishes.
#
# `llm-agents.packages.<system>` is built against upstream's nixpkgs, which is
# exactly what their CI pushed — hence the separate `llm-agents-prebuilt`
# input, which does not follow our nixpkgs. It has to be a *second* input:
# dropping `follows` from `llm-agents` itself would also re-hash everything
# coming through shared-nixpkgs, because upstream pins `bun` from its own
# nixpkgs (`bun = pkgsFor.${system}.bun`). Those paths are not on any cache
# (shared-nixpkgs output is per-consumer), so the whole agent set would have
# rebuilt from source. Measured: claude-code moved ydzfb85i -> 7q94v573, and
# 7q94v573 is not valid on cache.numtide.com.
#
# The closure duplication this trades for is small — at the time of writing,
# 45 of omp's 46 runtime paths were already in the store from our own nixpkgs.
# That overlap is a function of how far apart the two revs are; expect a
# duplicate glibc/gcc-lib set whenever they straddle a stdenv bump.
#
# Everything else stays on shared-nixpkgs, where sharing our nixpkgs is the
# point. Only bun2nix packages have this pathology — check upstream
# `packages/<name>/package.nix` for `buildBunPackage` before adding here.
{ inputs, system }:
_final: prev: {
  llm-agents = prev.llm-agents // {
    inherit (inputs.llm-agents-prebuilt.packages.${system}) omp;
  };
}
