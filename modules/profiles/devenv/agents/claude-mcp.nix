# Claude MCP registration must use `claude mcp add-json --scope user` so
# activation does not overwrite auth/state in ~/.claude.json.
{
  dotfilesLib,
  lib,
  osConfig,
  pkgs-small,
  ...
}:
let
  mcpRegistry = dotfilesLib.mcpServers { inherit lib osConfig; };
  inherit (mcpRegistry) needsSharedServerMaintenance;
  mcpServers = mcpRegistry.sharedServers;

  registerScript = lib.concatMapStringsSep "\n" (
    name:
    let
      payload = builtins.toJSON mcpServers.${name};
    in
    ''
      if ! printf '%s\n' "$existing" | grep -q "^${name}:"; then
        echo "claude-mcp: registering ${name}"
        if command_output=$(claude mcp add-json --scope user ${lib.escapeShellArg name} ${lib.escapeShellArg payload} 2>&1); then
          printf '%s\n' "$command_output" | sed 's/^/  /'
        else
          printf '%s\n' "$command_output" | sed 's/^/  /'
          echo "claude-mcp: failed to register ${name} (will retry next switch)"
        fi
      fi
    ''
  ) (lib.attrNames mcpServers);
in
lib.mkIf needsSharedServerMaintenance {
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs-small.claude-code
      ]
    }:$PATH

    existing=$(claude mcp list 2>/dev/null || true)
    ${registerScript}
  '';
}
