# Declarative pi MCP servers — merged into ~/.pi/agent/mcp.json (pi's actual
# MCP config path) at activation. Pi's other state (`imports`, runtime-added
# fields like `directTools`, etc.) is preserved; we only own the keys we
# declare, per-server.
#
# Claude Code consumes its own MCP servers via `claude mcp add-json --scope user`,
# wired in ./claude-mcp.nix (~/.claude.json holds other state we don't want
# to manage by symlink/merge).
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
