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

  mcpServers = import ./mcp-servers.nix;

  mcpDir = "${homeDir}/.pi/agent";
  mcpFile = "${mcpDir}/mcp.json";

  esc = lib.escapeShellArg;

  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
in
  lib.mkIf (agentsEnabled && mcpServers != {}) {
    home.activation.piMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils]}:$PATH
      mkdir -p ${esc mcpDir}
      if ! jq -e . ${esc mcpFile} >/dev/null 2>&1; then
        printf '%s\n' '{}' >${esc mcpFile}
      fi
      tmp=$(mktemp)
      jq --argjson servers ${esc (builtins.toJSON mcpServers)} \
        'reduce ($servers | to_entries[]) as $e (.;
          .mcpServers[$e.key] = ((.mcpServers[$e.key] // {}) + $e.value))' \
        ${esc mcpFile} >"$tmp" && mv "$tmp" ${esc mcpFile}
    '';
  }
