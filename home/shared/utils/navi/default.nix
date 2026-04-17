{
  pkgs,
  config,
  lib,
  isDarwin ? false,
  ...
}: let
  # Cross-platform cheats (P1–P4). Collected from ./cheats/*.cheat into a
  # single /nix/store directory so navi can watch a read-only tree.
  sharedCheats = pkgs.runCommand "navi-cheats-shared" {} ''
    mkdir -p $out
    cp -r ${./cheats}/* $out/
  '';

  # NixOS-only cheats (lspci, sensors, niri, systemctl, docker, fwupdmgr, …).
  nixosCheats = pkgs.runCommand "navi-cheats-nixos" {} ''
    mkdir -p $out
    cp -r ${./cheats-nixos}/* $out/
  '';

  # Darwin-only cheats (op, pbcopy, defaults, mdfind, sips, launchctl, …).
  darwinCheats = pkgs.runCommand "navi-cheats-darwin" {} ''
    mkdir -p $out
    cp -r ${./cheats-darwin}/* $out/
  '';
in {
  programs.navi.settings.cheats.paths =
    [
      "${sharedCheats}"
      "${config.home.homeDirectory}/.local/share/navi/cheats"
    ]
    ++ lib.optionals (!isDarwin) ["${nixosCheats}"]
    ++ lib.optionals isDarwin ["${darwinCheats}"];
}
