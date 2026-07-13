# omp uses the pi/oh-my-pi MCP config shape:
# https://github.com/can1357/oh-my-pi/blob/main/docs/mcp-config.md
{
  dotfilesLib,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;

  mcpRegistry = dotfilesLib.mcpServers { inherit lib osConfig; };

  mcpDir = "${homeDir}/.omp/agent";
  mcpFile = "${mcpDir}/mcp.json";

  inherit (mcpRegistry) needsSharedServerMaintenance;
in
lib.mkIf needsSharedServerMaintenance {
  home.activation.ompMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:$PATH
    ${mcpRegistry.mkMcpJsonMergeActivation { inherit mcpDir mcpFile; }}
  '';
}
