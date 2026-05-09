# Canonical stdio MCP server declarations. Consumed by:
#   - ./pi-mcp.nix
#       jq-merges these into ~/.pi/agent/mcp.json
#   - ./claude-mcp.nix
#       registers via `claude mcp add-json --scope user`
#   - ../../apps/ides/zed/settings/agents-and-mcp.nix
#       merges into Zed's `context_servers` alongside Zed-extension-managed
#       entries like mcp-server-context7 and mcp-server-github
#
# Shape: every entry uses `{ command, args }` — the lowest common denominator
# accepted by all three consumers. Per-consumer extras (e.g. Zed's optional
# `env`, pi's runtime-added `directTools`) are layered in by each consumer
# and don't belong in this canonical list.
{
  mcp-nixos = {
    command = "mcp-nixos";
    args = [];
  };
  "context-mode" = {
    command = "context-mode";
    args = [];
  };
}
