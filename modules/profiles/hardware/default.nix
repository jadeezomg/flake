# Hardware traits (`dotfiles.hardware.*`) — what a machine IS (radio, GPU
# vendor, CPU family), as opposed to `dotfiles.profiles.*` (what it's FOR).
# Options are declared centrally in ../default.nix; hosts set them in
# hosts/<name>/profiles.nix. Linux-only (imported when !isDarwin).
_: {
  imports = [
    ./wireless.nix
    ./gpu-nvidia.nix
    ./gpu-amd.nix
    ./gpu-intel.nix
  ];
}
