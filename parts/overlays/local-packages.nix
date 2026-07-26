# Auto-register every `packages/<name>/default.nix` as `pkgs.<name>` so consumer
# modules don't need brittle `pkgs.callPackage ../../../../../packages/<name>`
# paths.
#
# Two calling conventions are supported:
#   - `{ pkgs, lib, ... }:`   (most local packages — short-circuit and pass
#                              `pkgs = final`).
#   - `{ lib, rustPlatform, fetchFromGitHub, ... }:` (standard-nixpkgs
{
  lib,
  system,
  ...
}:
final: _prev:
let
  pkgRoot = ../../packages;

  pkgNames = import (pkgRoot + "/names.nix") { inherit lib system; };

  importPkg =
    name:
    let
      path = pkgRoot + "/${name}";
      fn = import path;
      args = builtins.functionArgs fn;
    in
    if args ? pkgs then
      (lib.makeOverridable fn) {
        pkgs = final;
        inherit lib;
      }
    else
      final.callPackage path { };
in
lib.genAttrs pkgNames importPkg
