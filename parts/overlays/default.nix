# Central overlay list. Add new overlays here and in their own file under ./.
# Each overlay is included per-system; use condition to restrict by system when needed.
{
  inputs,
  system,
}: let
  inherit (inputs.nixpkgs) lib;
  isX86_64Linux = system == "x86_64-linux";
in
  []
  # x86_64-linux: niri-flake, CachyOS kernel, framework-control (patched src hash)
  ++ (
    if isX86_64Linux
    then [
      inputs.niri.overlays.niri
      inputs.nix-cachyos-kernel.overlays.pinned
      (import ./framework-control.nix {inherit lib;})
    ]
    else []
  )
