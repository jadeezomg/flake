{
  lib,
  osConfig ? null,
}:
let
  availableSharedServers = {
    mcp-nixos = {
      command = "mcp-nixos";
      args = [ ];
    };
    context7-mcp = {
      command = "context7-mcp";
      args = [ ];
    };
  };

  # Work-only servers: remote streamable-HTTP endpoints that authenticate
  # interactively per client (OAuth on first `/mcp` use), so there is nothing to
  # install and no secret to wire. Gated on the work profile — only caya.
  availableWorkServers = {
    linear = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };
  };

  agentsEnabled =
    if osConfig == null then true else osConfig.dotfiles.profiles.devenv.agents.enable or false;

  workEnabled = if osConfig == null then false else osConfig.dotfiles.profiles.work.enable or false;

  esc = lib.escapeShellArg;

  workServers = if workEnabled then availableWorkServers else { };

  sharedServers = if agentsEnabled then availableSharedServers // workServers else { };

  mapSharedServers = transform: lib.mapAttrs transform sharedServers;

  needsSharedServerMaintenance = sharedServers != { };

  mkMcpJsonMergeActivation =
    {
      mcpDir,
      mcpFile,
    }:
    ''
      if [ -e ${esc mcpFile} ] || [ ${esc (if sharedServers == { } then "0" else "1")} = 1 ]; then
        mkdir -p ${esc mcpDir}
        if ! jq -e . ${esc mcpFile} >/dev/null 2>&1; then
          printf '%s\n' '{}' >${esc mcpFile}
        fi
        tmp=$(mktemp)
        jq --argjson servers ${esc (builtins.toJSON sharedServers)} \
          '(.mcpServers //= {}) |
           reduce ($servers | to_entries[]) as $e (.;
             .mcpServers[$e.key] = ((.mcpServers[$e.key] // {}) + $e.value))' \
          ${esc mcpFile} >"$tmp" && mv "$tmp" ${esc mcpFile}
      fi
    '';

  # Zed's context_servers shape differs per transport: local servers keep
  # command/args, remote ones carry only `url` (plus optional headers) and Zed
  # runs the MCP OAuth flow when no Authorization header is set. `type` is a
  # claude/pi/omp key, so it is dropped here.
  toZedContextServer =
    _name: server:
    if server ? url then
      {
        inherit (server) url;
        enabled = server.enabled or true;
        remote = true;
      }
    else
      server
      // {
        enabled = server.enabled or true;
        remote = server.remote or false;
      };

  toZedContextServers =
    extensionManagedServers:
    let
      collisions = lib.intersectLists (lib.attrNames extensionManagedServers) (
        lib.attrNames sharedServers
      );
    in
    assert lib.assertMsg (collisions == [ ])
      "Zed MCP shared server name collision with extension-managed entries: ${lib.concatStringsSep ", " collisions}";
    extensionManagedServers // mapSharedServers toZedContextServer;
in
{
  inherit
    agentsEnabled
    sharedServers
    mapSharedServers
    mkMcpJsonMergeActivation
    toZedContextServers
    needsSharedServerMaintenance
    ;
}
