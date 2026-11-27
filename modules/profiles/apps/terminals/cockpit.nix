# cockpit (packages/cockpit-herdr) in Herdr.app. After each switch,
# `cockpit app install` copies cockpit's layouts and mod into
# ~/.config/herdr-app, merges its layout keys into keys.json (your own keys
# stay), and writes cockpit.json with the path of this version's binary. The
# first install also switches the window to the cockpit layout once.
#
# `cockpit setup` does not run here. It would write ~/.codex/config.toml and
# ~/.omp/agent/mcp.json, which the flake owns, and it would install a herdr
# TUI plugin. Options go through the app's Cockpit settings dialog, which
# writes ~/.config/cockpit/config.json.
{ lib, pkgs, ... }:
let
  cockpit = pkgs.cockpit-herdr;
in
{
  home.packages = [ cockpit ];

  # Nix updates cockpit, so its hub must not look for new releases. The hub
  # reads its environment from the login shell.
  home.sessionVariables.COCKPIT_PUBLISHED_URL = "off";

  home.activation.cockpitApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe cockpit} app install >/dev/null \
      || echo "cockpit: app install failed (will retry next switch)"
  '';
}
