# Caya profile: composed from base, spaces, and pins (essentials + folders + per-workspace pins in skifli format).
# Regenerate spaces.nix / pins.nix from the live session: `just zen-sync` (or `zen-sync`).
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
