# Declarative omp (oh-my-pi) MCP servers — merged into ~/.omp/agent/mcp.json.
# Uses the same shape as ~/.pi/agent/mcp.json (omp inherits its mcp config
# format from pi-mono via fork). The `mcpServers` schema is documented at
# https://github.com/can1357/oh-my-pi/blob/main/docs/mcp-config.md.
#
# We do NOT manage omp's plugin set declaratively — omp moved away from
# pi's `settings.json .packages` array to a bun-driven plugin manager
# (`omp plugin install <pkg>` writes ~/.omp/plugins/package.json and runs
# `bun install`). For declarative parity with pi-packages.nix, we'd need
# bun on PATH at HM activation time and a chicken-and-egg ordering with
# the agents profile build. Not worth it for the tiny package set that
# survives omp's built-ins (most pi packages are redundant: browser is
# baked in as `puppeteer`, MCP is native, openrouter has first-class
# routing). Manual install path: `omp plugin install context-mode`.
#
# Pi's equivalent declarative manifest lives in ./pi-mcp.nix; settings
# (defaultModel etc.) for pi go in ./pi-packages.nix. omp has neither
# counterpart by design (config.yml is omp's own state).
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

  mcpDir = "${homeDir}/.omp/agent";
  mcpFile = "${mcpDir}/mcp.json";

  agentsEnabled = mcpRegistry.agentsEnabled;
in
  lib.mkIf (agentsEnabled && mcpServers != {}) {
    home.activation.ompMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils]}:$PATH
      ${mcpRegistry.mkMcpJsonMergeActivation {inherit mcpDir mcpFile;}}
    '';
  }
