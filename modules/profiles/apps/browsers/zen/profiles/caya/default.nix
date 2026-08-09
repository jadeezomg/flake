# Caya profile: composed from base, spaces, and pins (essentials + folders + per-space pins).
# Regenerate spaces.nix / pins.nix from the live session: `just zen-sync` (or `zen-sync`).
# pins.nix must merge last: after the next sync on caya it re-emits `spaces` with
# each space's pins nested under it, built from the metadata in spaces.nix.
# The committed pins.nix still uses the older flat `workspace = ...` form, which
# the module accepts; run zen-sync on caya to convert it.
{
  extensions,
  sharedSearch,
  sharedSettings,
  ...
}:
let
  base = import ./base.nix { inherit extensions sharedSettings sharedSearch; };
  spaces = import ./spaces.nix { };
  pinsModule = import ./pins.nix { };
in
base // spaces // pinsModule
