# Drop obsolete shared MCP servers from Zed's mutable settings.json.
# HM's zed-editor impure merge (`$dynamic * $static`) preserves keys that only
# exist in the live file, so flake removal alone is not enough.
{
  dotfilesLib,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  mcpRegistry = dotfilesLib.mcpServers { inherit lib osConfig; };
  inherit (mcpRegistry) needsSharedServerMaintenance mkZedObsoleteRemovalActivation;
  settingsFile = "${config.xdg.configHome}/zed/settings.json";
  configDir = "${config.xdg.configHome}/zed";
in
lib.mkIf needsSharedServerMaintenance {
  home.activation.zedObsoleteMcp = lib.hm.dag.entryAfter [ "zedSettingsActivation" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
        pkgs.glib
      ]
    }:$PATH
    ${mkZedObsoleteRemovalActivation { inherit settingsFile configDir; }}
  '';
}
