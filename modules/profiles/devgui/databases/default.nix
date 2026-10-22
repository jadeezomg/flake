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
dotfilesLib.mkProfile {
  path = [ "devgui" ];
  imports = lib.optionals isDarwin [ ./darwin.nix ];
  linuxPackages = pkgs: [ pkgs.tabularis ];
} args
