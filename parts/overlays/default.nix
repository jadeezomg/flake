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
  inputs.llm-agents.overlays.shared-nixpkgs
  (import ./omp-upstream-nixpkgs.nix {
    inherit inputs lib system;
    expiry = expiryFor "omp-upstream-nixpkgs";
  })
  (import ./local-packages.nix { inherit lib system; })
  (import ./cargo-generate-darwin-canonicalize-test.nix {
    inherit lib system;
    expiry = expiryFor "cargo-generate-darwin-canonicalize-test";
  })
  (import ./xwayland-satellite-menu-flicker.nix {
    inherit lib system;
    expiry = expiryFor "xwayland-satellite-menu-flicker";
  })
  (import ./sops-nix-go-builder.nix {
    inherit inputs lib;
    expiry = expiryFor "sops-nix-go-builder";
  })
  (import ./showtime-mpris-volume-deadlock.nix {
    inherit lib system;
    expiry = expiryFor "showtime-mpris-volume-deadlock";
  })
  # Standing pin, not a workaround — no expiry guard (see the file's header).
  (import ./skhd-pinned-darwin.nix { inherit inputs system; })
]
++ (if isX86_64Linux then [ inputs.nix-cachyos-kernel.overlays.pinned ] else [ ])
