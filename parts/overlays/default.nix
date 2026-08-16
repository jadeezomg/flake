# Central overlay list. Add new overlays here and in their own file under ./.
# Each overlay is included per-system; use condition to restrict by system when needed.
#
# Workaround overlays take `expiry` and guard themselves with lib/expiry.nix, so
# they warn during evaluation once nixpkgs makes them redundant. The name bound
# here is what the warning points at — keep it matching the file name.
{
  inputs,
  system,
}:
let
  inherit (inputs.nixpkgs) lib;
  isX86_64Linux = system == "x86_64-linux";
  # Shared with modules as `dotfilesLib.expiry`; overlays name their own file.
  expiryFor = name: import ../../lib/expiry.nix { inherit lib; } "parts/overlays/${name}.nix";
in
[
  # AI agent CLIs (codex, claude-code, pi, omp, herdr, …) under
  # `pkgs.llm-agents.*`. Pre-built on https://cache.numtide.com when our
  # nixpkgs rev is close to theirs.
  inputs.llm-agents.overlays.shared-nixpkgs
  (import ./local-packages.nix { inherit lib system; })
  (import ./python-package-fixes.nix {
    inherit lib;
    expiry = expiryFor "python-package-fixes";
  })
  # Standing pin, not a workaround — no expiry guard (see the file's header).
  (import ./skhd-pinned-darwin.nix { inherit inputs system; })
  (import ./zed-pinned-darwin.nix {
    inherit inputs lib system;
    expiry = expiryFor "zed-pinned-darwin";
  })
]
++ (if isX86_64Linux then [ inputs.nix-cachyos-kernel.overlays.pinned ] else [ ])
