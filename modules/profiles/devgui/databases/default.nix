# GUI counterpart of devenv.databases (rainfrog TUI stays headless-side).
# Darwin takes tabularis from a homebrew cask for now: ./darwin.nix says why.
# The `homebrew.*` namespace only exists on darwin, hence the import gate.
# When ./darwin.nix retires, delete it and move tabularis back to `packages`.
{
  dotfilesLib,
  isDarwin ? false,
  lib,
  ...
}@args:
let
  # tabularis 0.30.0 does not build on our nixos-unstable pin, and only nixpkgs
  # can fix it:
  #   - sqlx-sqlite links -lsqlite3, but `sqlite` is missing from buildInputs
  #     (NixOS/nixpkgs@4977bdc92270 adds it);
  #   - `zip = "4.2.0"` keeps zstd in its default features, so zstd-sys is
  #     compiled, and nixpkgs' Rust hook points zstd-sys at the system libzstd
  #     (cargo-setup-hook.sh exports ZSTD_SYS_USE_PKG_CONFIG=1) that the
  #     derivation does not provide.
  # Neither build reached cache.nixos.org, so enabling it costs a full Tauri
  # compile and then fails. Show it again once nixpkgs lists both inputs
  # itself. The condition reads the package's own buildInputs, so a channel
  # bump re-enables it without anyone editing this file.
  tabularisBuilds =
    pkgs:
    lib.all (name: lib.elem name (map (d: d.pname or "") pkgs.tabularis.buildInputs)) [
      "sqlite"
      "zstd"
    ];
in
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  imports = lib.optionals isDarwin [ ./darwin.nix ];
  linuxPackages = pkgs: lib.optional (tabularisBuilds pkgs) pkgs.tabularis;
} args
