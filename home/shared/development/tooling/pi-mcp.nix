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
  mcpServers = mcpRegistry.sharedServers;

  mcpDir = "${homeDir}/.pi/agent";
  mcpFile = "${mcpDir}/mcp.json";

  agentsEnabled = mcpRegistry.agentsEnabled;
in
  lib.mkIf (agentsEnabled && mcpServers != {}) {
    home.activation.piMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils]}:$PATH
      ${mcpRegistry.mkMcpJsonMergeActivation {inherit mcpDir mcpFile;}}
    '';
  }
