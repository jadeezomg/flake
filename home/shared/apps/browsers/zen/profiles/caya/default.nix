# Caya profile: composed from base, spaces, and pins (essentials + folders + per-workspace pins in skifli format).
# Run sync_caya_from_session.py to update spaces and pins from the live Zen session.
{
  pkgs,
  extensions,
  ...
}: let
  base = import ./base.nix {inherit pkgs extensions;};
  spaces = import ./spaces.nix {};
  pinsModule = import ./pins.nix {};
in
  base
  // spaces
  // pinsModule
