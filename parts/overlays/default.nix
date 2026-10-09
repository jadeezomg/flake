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
  # Upstream's own build, not `overlays.shared-nixpkgs`. shared-nixpkgs rebuilds
  # every package against our nixpkgs, which changes each derivation hash and
  # misses cache.numtide.com for all of them (measured 2026-10-01: 0 of 10 hit).
  # Three of them are Rust compiles. Take the cached builds instead.
  (_final: _prev: { llm-agents = inputs.llm-agents.packages.${system}; })
  (import ./local-packages.nix { inherit lib system; })
  (import ./cargo-generate-darwin-canonicalize-test.nix {
    inherit lib system;
    expiry = expiryFor "cargo-generate-darwin-canonicalize-test";
  })
  (import ./sops-nix-go-builder.nix {
    inherit inputs lib;
    expiry = expiryFor "sops-nix-go-builder";
  })
  (import ./showtime-mpris-volume-deadlock.nix {
    inherit lib system;
    expiry = expiryFor "showtime-mpris-volume-deadlock";
  })
  (import ./dsh-official-node-darwin.nix {
    inherit lib system;
    expiry = expiryFor "dsh-official-node-darwin";
  })
  # Standing pin, not a workaround — no expiry guard (see the file's header).
  (import ./skhd-pinned-darwin.nix { inherit inputs system; })
]
++ (if isX86_64Linux then [ inputs.nix-cachyos-kernel.overlays.pinned ] else [ ])
