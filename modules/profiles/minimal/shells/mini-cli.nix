# `mini <cmd>`: the mini-nix repo's Justfile, installed as a command so the
# recipes live with the mini configuration instead of in this flake.
#
# The repo is a checkout at ~/git/mini-nix, so this is a thin exec rather than a
# packaged derivation. Hosts without the checkout get a clear error from the
# wrapper script when they run `mini`.
{ config, pkgs, ... }:
let
  miniNix = "${config.home.homeDirectory}/git/mini-nix/bin/mini";
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "mini" ''
      exec ${miniNix} "$@"
    '')
  ];
}
