# skhd's Accessibility (TCC) grant is keyed to its exact store path, which
# nixpkgs bumps churn on every `flake update` — silently breaking the Vicinae
# Hyper+Space hotkey (skhd aborts its event tap: "must be run with accessibility
# access!") until re-granted against the new binary. Pin skhd from the fixed
# `nixpkgs-skhd` rev so the path (and grant) only move on a deliberate bump.
# Darwin only; skhd is macOS-only. Bump `nixpkgs-skhd` + re-grant Accessibility
# together, or drop this overlay + input to unpin.
{
  inputs,
  system,
}:
_final: _prev:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
if !isDarwin then
  { }
else
  {
    skhd = inputs.nixpkgs-skhd.legacyPackages.${system}.skhd;
  }
