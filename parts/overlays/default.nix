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
  # Surface every `packages/<name>` as `pkgs.<name>` (handles both
  # `{pkgs, lib}` and standard-nixpkgs `callPackage` signatures, with
  # per-package system gates inside the overlay).
  (import ./local-packages.nix { inherit lib system; })
  # Surface external flake-input packages (e.g. `hunk`) as `pkgs.<name>`.
  (import ./flake-packages.nix { inherit inputs system; })
  (import ./vscode-langservers-node-esm.nix)
  (import ./direnv-skip-check-darwin.nix { inherit system; })
  (import ./zed-pinned-darwin.nix { inherit inputs system; })
  (import ./nono-skip-check-darwin.nix { inherit system; })
  (import ./podman-platforms-darwin.nix { inherit system; })
  (import ./python-package-fixes.nix)
]
++ (if isX86_64Linux then [ inputs.nix-cachyos-kernel.overlays.pinned ] else [ ])
