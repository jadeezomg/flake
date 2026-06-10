# Auto-register every `packages/<name>/default.nix` as `pkgs.<name>` so consumer
# modules don't need brittle `pkgs.callPackage ../../../../../packages/<name>`
# paths.
#
# Two calling conventions are supported:
#   - `{ pkgs, lib, ... }:`   (most local packages — short-circuit and pass
#                              `pkgs = final`).
#   - `{ lib, rustPlatform, fetchFromGitHub, ... }:` (standard-nixpkgs
#                              callPackage signature — e.g. framework-control).
#
# The name list (and per-package system gates, e.g. framework-control →
# x86_64-linux only) comes from `packages/names.nix`, shared with
# `parts/packages.nix` so the overlay and the flake output can't drift.
{
  lib,
  system,
  ...
}: final: _prev: let
  pkgRoot = ../../packages;

  pkgNames = import (pkgRoot + "/names.nix") {inherit lib system;};

  importPkg = name: let
    path = pkgRoot + "/${name}";
    fn = import path;
    args = builtins.functionArgs fn;
  in
    if args ? pkgs
    then
      fn {
        pkgs = final;
        inherit lib;
      }
    else final.callPackage path {};
in
  lib.genAttrs pkgNames importPkg
