# zed-editor 1.9.0 fails to build on Hydra for aarch64-darwin, so pin 1.8.2
# from the nixpkgs rev of the last green build (hydra.nixos.org/build/333610316)
# via the separate `nixpkgs-zed` input. Darwin only; Linux keeps the main
# nixpkgs version. Drop this and the input once zed-editor builds again.
{
  inputs,
  system,
}: _final: _prev: let
  isDarwin = builtins.match ".*-darwin" system != null;
in
  if !isDarwin
  then {}
  else {
    zed-editor = inputs.nixpkgs-zed.legacyPackages.${system}.zed-editor;
  }
