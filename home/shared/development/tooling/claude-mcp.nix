# Declarative user-scoped MCP servers for Claude Code (`~/.claude.json`).
#
# `claude mcp add-json --scope user <name> <payload>` is the supported way to
# register a stdio MCP server without overwriting the rest of `~/.claude.json`
# (which holds auth tokens and other state we don't want to manage).
#
# Activation is idempotent via `claude mcp list` grep — re-running on each
# switch is a no-op once an entry exists. Failures are logged and don't block
# activation; a later switch retries.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
  homeDir = config.home.homeDirectory;

  mcpServers = import ./mcp-servers.nix;

  registerScript =
    lib.concatMapStringsSep "\n"
    (name: let
      payload = builtins.toJSON mcpServers.${name};
    in ''
      if ! printf '%s\n' "$existing" | grep -q "^${name}:"; then
        echo "claude-mcp: registering ${name}"
        claude mcp add-json --scope user ${lib.escapeShellArg name} ${lib.escapeShellArg payload} 2>&1 | sed 's/^/  /' || \
          echo "claude-mcp: failed to register ${name} (will retry next switch)"
      fi
    '')
    (lib.attrNames mcpServers);
in
  lib.mkIf (agentsEnabled && mcpServers != {}) {
    home.activation.claudeMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs.claude-code]}:$PATH
      mkdir -p ${lib.escapeShellArg "${homeDir}/.claude"}

      existing=$(claude mcp list 2>/dev/null || true)
      ${registerScript}
    '';
  }
