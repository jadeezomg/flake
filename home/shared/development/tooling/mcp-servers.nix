{
  lib,
  osConfig ? null,
}: let
  sharedServers = {
    mcp-nixos = {
      command = "mcp-nixos";
      args = [];
    };
    "context-mode" = {
      command = "context-mode";
      args = [];
    };
  };

  agentsEnabled =
    if osConfig == null
    then true
    else osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;

  esc = lib.escapeShellArg;

  mapSharedServers = transform: lib.mapAttrs transform sharedServers;

  mkMcpJsonMergeActivation = {
    mcpDir,
    mcpFile,
  }: ''
    mkdir -p ${esc mcpDir}
    if ! jq -e . ${esc mcpFile} >/dev/null 2>&1; then
      printf '%s\n' '{}' >${esc mcpFile}
    fi
    tmp=$(mktemp)
    jq --argjson servers ${esc (builtins.toJSON sharedServers)} \
      'reduce ($servers | to_entries[]) as $e (.;
        .mcpServers[$e.key] = ((.mcpServers[$e.key] // {}) + $e.value))' \
      ${esc mcpFile} >"$tmp" && mv "$tmp" ${esc mcpFile}
  '';

  toZedContextServer = _name: server:
    server
    // {
      settings = server.settings or {};
      enabled = server.enabled or true;
      remote = server.remote or false;
    };

  toZedContextServers = extensionManagedServers: let
    collisions =
      lib.intersectLists
      (lib.attrNames extensionManagedServers)
      (lib.attrNames sharedServers);
  in
    assert lib.assertMsg (collisions == [])
    "Zed MCP shared server name collision with extension-managed entries: ${lib.concatStringsSep ", " collisions}";
      extensionManagedServers // mapSharedServers toZedContextServer;
in {
  inherit agentsEnabled sharedServers mapSharedServers mkMcpJsonMergeActivation toZedContextServers;
}
