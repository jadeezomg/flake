# zed-editor has no aarch64-darwin substitute on nixos-unstable: Hydra's last
# successful `zed-editor.aarch64-darwin` build is 1.13.1 (build 340698173,
# 2026-08-02)
# (https://hydra.nixos.org/job/nixpkgs/unstable/zed-editor.aarch64-darwin), so
# every newer rev makes caya compile Zed's Rust tree locally. Pin zed-editor
# from `nixpkgs-zed`, the last rev whose Darwin output is in cache.nixos.org.
# Darwin only — x86_64-linux zed-editor is cached at the current unstable rev,
# so NixOS hosts stay on it.
#
# Cache availability is not observable at eval time, so this uses recheckWhen:
# it keeps the pin and nags once unstable moves a few releases past the version
# that was verified broken (1.14.2). Verify with:
#   nix path-info --store https://cache.nixos.org "$(nix eval --raw <flake>#legacyPackages.aarch64-darwin.zed-editor)"
# Then bump `nixpkgs-zed` to a rev Hydra has built, or delete this overlay and
# the input once unstable is cached again.
{
  expiry,
  inputs,
  lib,
  system,
}:
_final: prev:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
if !isDarwin then
  { }
else
  {
    zed-editor = expiry.recheckWhen {
      stale = lib.versionAtLeast prev.zed-editor.version "1.17";
      reason = "nixpkgs reached zed-editor 1.17 (no Darwin substitute verified at 1.14.2); re-check whether Hydra caches zed-editor.aarch64-darwin again.";
    } inputs.nixpkgs-zed.legacyPackages.${system}.zed-editor;
  }
