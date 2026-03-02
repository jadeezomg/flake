# Central overlay list. Add new overlays here and in their own file under ./.
# Each overlay is included per-system; use condition to restrict by system when needed.
{
  inputs,
  system,
}: let
  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
  isX86_64Linux = system == "x86_64-linux";
in
  []
  # Linux-only: gvfs Google Drive in Nautilus
  ++ (
    if isLinux
    then [(import ./gvfs-google-drive.nix)]
    else []
  )
  # x86_64-linux: CachyOS kernel
  ++ (
    if isX86_64Linux
    then [inputs.nix-cachyos-kernel.overlays.pinned]
    else []
  )
