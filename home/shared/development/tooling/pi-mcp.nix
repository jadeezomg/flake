# Claude Code MCP registration is separate; ~/.claude.json contains auth/state
# that must not be managed by symlink/merge.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;

  mcpRegistry = import ./mcp-servers.nix {inherit lib osConfig;};

  mcpDir = "${homeDir}/.pi/agent";
  mcpFile = "${mcpDir}/mcp.json";

  inherit (mcpRegistry) needsSharedServerMaintenance;
in
  lib.mkIf needsSharedServerMaintenance {
    home.activation.piMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${
        lib.makeBinPath [
          pkgs.jq
          pkgs.coreutils
        ]
      }:$PATH
      ${mcpRegistry.mkMcpJsonMergeActivation {inherit mcpDir mcpFile;}}
    '';
  }
