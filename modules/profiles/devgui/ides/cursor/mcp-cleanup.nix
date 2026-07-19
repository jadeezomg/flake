# Drop obsolete shared MCP servers from Cursor's user mcp.json when present.
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
  inherit (mcpRegistry) needsSharedServerMaintenance mkCursorObsoleteRemovalActivation;
  cursorDir = "${config.home.homeDirectory}/.cursor";
  mcpFile = "${cursorDir}/mcp.json";
  cliConfigFile = "${cursorDir}/cli-config.json";
in
lib.mkIf needsSharedServerMaintenance {
  home.activation.cursorObsoleteMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:$PATH
    ${mkCursorObsoleteRemovalActivation { inherit mcpFile cliConfigFile; }}
  '';
}
