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

  agentsEnabled =
    if osConfig == null then true else osConfig.dotfiles.profiles.devenv.agents.enable or false;

  esc = lib.escapeShellArg;

  sharedServers = if agentsEnabled then availableSharedServers else { };

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

  toZedContextServer =
    _name: server:
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
