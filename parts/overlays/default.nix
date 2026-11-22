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
  (import ./debugpy-darwin-lldb-test.nix {
    inherit lib system;
    expiry = expiryFor "debugpy-darwin-lldb-test";
  })
  (import ./sops-nix-go-builder.nix {
    inherit inputs lib;
    expiry = expiryFor "sops-nix-go-builder";
  })
  (import ./showtime-mpris-volume-deadlock.nix {
    inherit lib system;
    expiry = expiryFor "showtime-mpris-volume-deadlock";
  })
  (import ./dsh-official-node.nix {
    inherit lib system;
    expiry = expiryFor "dsh-official-node";
  })
  (import ./open-webui-otel-system-metrics.nix {
    inherit lib;
    expiry = expiryFor "open-webui-otel-system-metrics";
  })
  (import ./whisparr-code-search.nix {
    inherit lib system;
    expiry = expiryFor "whisparr-code-search";
  })
  (import ./netwatch-landlock-fastopen-test.nix {
    inherit lib system;
    expiry = expiryFor "netwatch-landlock-fastopen-test";
  })
  (import ./nix-update-flake-store-path.nix {
    inherit lib;
    expiry = expiryFor "nix-update-flake-store-path";
  })
  (import ./protonup-rs-system-zstd.nix {
    inherit lib system;
    expiry = expiryFor "protonup-rs-system-zstd";
  })
  # Standing pin, not a workaround — no expiry guard (see the file's header).
  (import ./skhd-pinned-darwin.nix { inherit inputs system; })
]
++ (
  if isX86_64Linux then
    [
      inputs.nix-cachyos-kernel.overlays.pinned
      # Upstream's own derivation (source build wrapped in steam-run-free).
      # Their flake only supports x86_64-linux, hence the gate.
      inputs.lightforge.overlays.default
    ]
  else
    [ ]
)
