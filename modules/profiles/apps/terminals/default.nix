{
  dotfilesLib,
  lib,
  pkgs-small,
  ...
}@args:
let
  inherit (dotfilesLib.expiry { inherit lib; } "modules/profiles/apps/terminals/default.nix")
    expireWhen
    ;
in
dotfilesLib.mkProfile {
  path = [ "apps" ];
  # HM halves — plain Home Manager modules, pushed to every user when the
  # profile is on (./ghostty.nix branches on isDarwin internally).
  hm = [
    ./ghostty.nix
    ./kitty.nix
  ];

  # The herdr desktop app (`herdr-app`, Herdr.app on macOS) on top of
  # herdr-core. nixpkgs#581031 reached nixos-unstable-small first.
  packages = pkgs: [
    (expireWhen {
      fixed = pkgs ? herdr-desktop;
      reason = "nixos-unstable now ships herdr-desktop (nixpkgs#581031).";
      fallback = pkgs.herdr-desktop;
    } pkgs-small.herdr-desktop)
  ];

  # Linux-only (ghostty is broken on darwin in nixpkgs; terminal apps on
  # macOS come from homebrew / HM configs instead).
  linuxPackages =
    pkgs: with pkgs; [
      ghostty
      kitty
    ];
} args
