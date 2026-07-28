# Central overlay list. Add new overlays here and in their own file under ./.
# Each overlay is included per-system; use condition to restrict by system when needed.
{
  inputs,
  system,
}:
let
  inherit (inputs.nixpkgs) lib;
  isX86_64Linux = system == "x86_64-linux";
in
[
  # AI agent CLIs (codex, claude-code, pi, omp, cursor-agent, …) under
  # `pkgs.llm-agents.*`. Pre-built on https://cache.numtide.com when our
  # nixpkgs rev is close to theirs.
  inputs.llm-agents.overlays.shared-nixpkgs
  # Surface every `packages/<name>` as `pkgs.<name>` (handles both
  # `{pkgs, lib}` and standard-nixpkgs `callPackage` signatures, with
  # per-package system gates inside the overlay).
  (import ./local-packages.nix { inherit lib system; })
  (import ./vscode-langservers-node-esm.nix)
  (import ./direnv-skip-check-darwin.nix { inherit system; })
  (import ./nono-skip-check-darwin.nix { inherit system; })
  (import ./python-package-fixes.nix)
  # lact + niri: libdisplay-info-sys needs <0.4.0 until nixpkgs#546155 lands.
  (import ./lact-libdisplay-info-fix.nix { inherit lib system; })
  (import ./skhd-pinned-darwin.nix { inherit inputs system; })
]
++ (if isX86_64Linux then [ inputs.nix-cachyos-kernel.overlays.pinned ] else [ ])
