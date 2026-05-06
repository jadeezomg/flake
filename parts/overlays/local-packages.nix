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
# Per-package system gates live in `systemFilter` below — packages that
# shouldn't be evaluated on every system (currently just framework-control)
# get their condition checked here.
{
  lib,
  system,
  ...
}: final: _prev: let
  pkgRoot = ../../packages;

  systemFilter = name:
    if name == "framework-control"
    then system == "x86_64-linux"
    else true;

  isLocalPkg = name: type:
    type
    == "directory"
    && builtins.pathExists (pkgRoot + "/${name}/default.nix")
    && systemFilter name;

  pkgNames =
    builtins.attrNames
    (lib.filterAttrs isLocalPkg (builtins.readDir pkgRoot));

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
