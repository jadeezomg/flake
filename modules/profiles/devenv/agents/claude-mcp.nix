# Claude MCP registration must use `claude mcp add-json --scope user` so
# activation does not overwrite auth/state in ~/.claude.json.
{
  dotfilesLib,
  config,
  lib,
  osConfig,
  pkgs-small,
  ...
}: let
  mcpRegistry = dotfilesLib.mcpServers {inherit lib osConfig;};
  inherit (mcpRegistry) needsSharedServerMaintenance mkClaudeObsoleteRemovalActivation;
  mcpServers = mcpRegistry.sharedServers;
  homeDir = config.home.homeDirectory;

  registerScript = lib.concatMapStringsSep "\n" (
    name: let
      payload = builtins.toJSON mcpServers.${name};
    in ''
      if ! printf '%s\n' "$existing" | grep -q "^${name}:"; then
        echo "claude-mcp: registering ${name}"
        claude mcp add-json --scope user ${lib.escapeShellArg name} ${lib.escapeShellArg payload} 2>&1 | sed 's/^/  /' || \
          echo "claude-mcp: failed to register ${name} (will retry next switch)"
      fi
    ''
  ) (lib.attrNames mcpServers);
in
  lib.mkIf needsSharedServerMaintenance {
    home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs-small.claude-code]}:$PATH
      mkdir -p ${lib.escapeShellArg "${homeDir}/.claude"}

      existing=$(claude mcp list 2>/dev/null || true)
      ${mkClaudeObsoleteRemovalActivation}
      existing=$(claude mcp list 2>/dev/null || true)
      ${registerScript}
    '';
  }
