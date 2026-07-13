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
  };

  agentsEnabled =
    if osConfig == null then true else osConfig.dotfiles.profiles.devenv.agents.enable or false;

  esc = lib.escapeShellArg;

  sharedServers = if agentsEnabled then availableSharedServers else { };

  mapSharedServers = transform: lib.mapAttrs transform sharedServers;
  obsoleteSharedServers = [ "context-mode" ];

  needsSharedServerMaintenance = sharedServers != { } || obsoleteSharedServers != [ ];

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
          --argjson obsolete ${esc (builtins.toJSON obsoleteSharedServers)} \
          '(.mcpServers //= {}) |
           reduce $obsolete[] as $name (.;
             del(.mcpServers[$name])) |
           reduce ($servers | to_entries[]) as $e (.;
             .mcpServers[$e.key] = ((.mcpServers[$e.key] // {}) + $e.value))' \
          ${esc mcpFile} >"$tmp" && mv "$tmp" ${esc mcpFile}
      fi
    '';

  mkClaudeObsoleteRemovalActivation = lib.concatMapStringsSep "\n" (name: ''
    if printf '%s\n' "$existing" | grep -q "^${name}:"; then
      echo "claude-mcp: removing obsolete ${name}"
      claude mcp remove --scope user ${esc name} 2>&1 | sed 's/^/  /' || \
        echo "claude-mcp: failed to remove obsolete ${name} (will retry next switch)"
    fi
  '') obsoleteSharedServers;

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
    mkClaudeObsoleteRemovalActivation
    toZedContextServers
    obsoleteSharedServers
    needsSharedServerMaintenance
    ;
}
