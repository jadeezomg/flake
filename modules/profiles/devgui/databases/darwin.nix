# Darwin-only leaf of devgui.databases. Hydra's aarch64-darwin build of nixpkgs
# tabularis 0.28.0 failed (https://hydra.nixos.org/build/350008829), so
# cache.nixos.org has no Darwin build and every switch compiled it from source.
# The package itself builds on Darwin: both nixpkgs-review runs on
# NixOS/nixpkgs#574195 passed. Hydra does not retry a failed derivation, but it
# builds a new tabularis version again. Until then, the upstream DMG from the
# homebrew cask stands in.
#
# Verified 2026-10-22 against nixpkgs tabularis 0.28.0 (nixos-unstable 02c087f).
{
  dotfilesLib,
  lib,
  pkgs,
  ...
}@args:
let
  inherit (dotfilesLib.expiry { inherit lib; } "modules/profiles/devgui/databases/darwin.nix")
    recheckWhen
    ;
in
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  extra.homebrew = {
    # mkDefault so the work profile keeps ownership of `enable` on caya, and
    # devgui alone still turns homebrew on for a darwin host without work.
    enable = lib.mkDefault true;

    casks =
      recheckWhen
        {
          stale = pkgs.tabularis.version != "0.28.0";
          reason = "nixpkgs tabularis is no longer 0.28.0 (no Darwin cache at 0.28.0); check whether cache.nixos.org serves its aarch64-darwin build (nix path-info --store https://cache.nixos.org on its outPath). If it does, delete this file and move tabularis back to `packages` in ./default.nix.";
        }
        [
          "tabularis" # Database GUI; nixpkgs on Linux (./default.nix)
        ];
  };
} args
