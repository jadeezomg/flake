# Caya profile: composed from base, spaces, and pins (essentials + folders + per-workspace pins in skifli format).
# Regenerate spaces.nix / pins.nix from the live session: zen_session.py sync (scripts/zen-session).
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
