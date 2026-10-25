# Darwin-only leaf of devenv.agents. tuios comes from Homebrew here: homebrew-core
# has 0.11.0 with arm64 bottles. The Nix package needs
# parts/overlays/tuios-0-11.nix (nixpkgs has 0.10.1, with GHSA-78rj-pghh-vh42),
# and no cache has that build for aarch64-darwin, so caya compiles it locally.
# The Linux hosts take the Nix package (./default.nix). When the overlay
# expires, move tuios back to `packages` in ./default.nix and delete this brew.
{ dotfilesLib, lib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  extra.homebrew = {
    # mkDefault so the work profile keeps ownership of `enable` on caya.
    enable = lib.mkDefault true;
    brews = [ "tuios" ];
  };
} args
