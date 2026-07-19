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

  # MCP server keys removed from shared registries; also deleted from mutable
  # agent/IDE JSON that impure-merges over static config (Zed, Cursor, pi/omp).
  obsoleteSharedServers = [ "context-mode" ];

  # Side channels that used to install the same tool outside the shared registry.
  obsoleteClaudePlugins = [ "context-mode@context-mode" ];
  obsoleteClaudeMarketplaces = [ "context-mode" ];
  obsoleteClaudeFiles = [ ".claude/hooks/context-mode-cache-heal.mjs" ];
  obsoleteOmpPlugins = [ "context-mode" ];
  obsoleteNpmGlobalPackages = [ "context-mode" ];

  needsSharedServerMaintenance =
    sharedServers != { }
    || obsoleteSharedServers != [ ]
    || obsoleteClaudePlugins != [ ]
    || obsoleteClaudeMarketplaces != [ ]
    || obsoleteClaudeFiles != [ ]
    || obsoleteOmpPlugins != [ ]
    || obsoleteNpmGlobalPackages != [ ];

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
      if command_output=$(claude mcp remove --scope user ${esc name} 2>&1); then
        printf '%s\n' "$command_output" | sed 's/^/  /'
      else
        printf '%s\n' "$command_output" | sed 's/^/  /'
        echo "claude-mcp: failed to remove obsolete ${name} (will retry next switch)"
      fi
    fi
  '') obsoleteSharedServers;

  mkClaudeObsoletePluginRemovalActivation = lib.concatStringsSep "\n" (
    (map (plugin: ''
      if claude plugin list 2>/dev/null | grep -q ${esc plugin}; then
        echo "claude-mcp: uninstalling obsolete plugin ${plugin}"
        if command_output=$(claude plugin uninstall --scope user -y --prune ${esc plugin} 2>&1); then
          printf '%s\n' "$command_output" | sed 's/^/  /'
        else
          printf '%s\n' "$command_output" | sed 's/^/  /'
          echo "claude-mcp: failed to uninstall ${plugin} (will retry next switch)"
        fi
      fi
    '') obsoleteClaudePlugins)
    ++ (map (marketplace: ''
      if claude plugin marketplace list 2>/dev/null | grep -q ${esc marketplace}; then
        echo "claude-mcp: removing obsolete marketplace ${marketplace}"
        if command_output=$(claude plugin marketplace remove --scope user ${esc marketplace} 2>&1); then
          printf '%s\n' "$command_output" | sed 's/^/  /'
        else
          printf '%s\n' "$command_output" | sed 's/^/  /'
          echo "claude-mcp: failed to remove marketplace ${marketplace} (will retry next switch)"
        fi
      fi
    '') obsoleteClaudeMarketplaces)
  );

  mkClaudeObsoleteFileRemovalActivation =
    homeDir:
    lib.concatMapStringsSep "\n" (relativePath: ''
      obsolete_file=${esc "${homeDir}/${relativePath}"}
      if [ -e "$obsolete_file" ]; then
        echo "claude-mcp: trashing obsolete file ${relativePath}"
        if command_output=$(gio trash "$obsolete_file" 2>&1); then
          printf '%s\n' "$command_output" | sed 's/^/  /'
        else
          printf '%s\n' "$command_output" | sed 's/^/  /'
          echo "claude-mcp: failed to trash $obsolete_file (will retry next switch)"
        fi
      fi
    '') obsoleteClaudeFiles;

  mkOmpObsoletePluginRemovalActivation = lib.concatMapStringsSep "\n" (plugin: ''
    if omp plugin list 2>/dev/null | grep -q ${esc plugin}; then
      echo "omp-mcp: uninstalling obsolete plugin ${plugin}"
      if command_output=$(omp plugin uninstall ${esc plugin} 2>&1); then
        printf '%s\n' "$command_output" | sed 's/^/  /'
      else
        printf '%s\n' "$command_output" | sed 's/^/  /'
        echo "omp-mcp: failed to uninstall ${plugin} (will retry next switch)"
      fi
    fi
  '') obsoleteOmpPlugins;

  mkNpmGlobalObsoleteRemovalActivation =
    homeDir:
    lib.concatMapStringsSep "\n" (pkg: ''
      npm_prefix=${esc "${homeDir}/.npm-global"}
      if [ -e "$npm_prefix/lib/node_modules/${pkg}" ] || [ -e "$npm_prefix/bin/${pkg}" ]; then
        echo "mcp-obsolete: uninstalling npm-global ${pkg}"
        if command_output=$(npm uninstall -g --prefix "$npm_prefix" ${esc pkg} 2>&1); then
          printf '%s\n' "$command_output" | sed 's/^/  /'
        else
          printf '%s\n' "$command_output" | sed 's/^/  /'
          echo "mcp-obsolete: failed to uninstall npm-global ${pkg} (will retry next switch)"
        fi
      fi
    '') obsoleteNpmGlobalPackages;

  mkJsonObsoleteRemovalActivation =
    {
      jsonFile,
      jqFilter,
    }:
    ''
      if [ -e ${esc jsonFile} ] && jq -e . ${esc jsonFile} >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --argjson obsolete ${esc (builtins.toJSON obsoleteSharedServers)} \
          ${esc jqFilter} ${esc jsonFile} >"$tmp" && mv "$tmp" ${esc jsonFile}
      fi
    '';

  # Zed impure-merges `$dynamic * $static`, so keys only present in the live
  # settings.json survive after they leave the flake. Delete them explicitly
  # after zedSettingsActivation. Also trash per-server config dirs under
  # ~/.config/zed/<name>/ when present.
  mkZedObsoleteRemovalActivation =
    {
      settingsFile,
      configDir,
    }:
    ''
      ${mkJsonObsoleteRemovalActivation {
        jsonFile = settingsFile;
        jqFilter = ''
          (.context_servers //= {}) |
          reduce $obsolete[] as $name (.;
            del(.context_servers[$name]))
        '';
      }}
      ${lib.concatMapStringsSep "\n" (name: ''
        obsolete_dir=${esc "${configDir}/${name}"}
        if [ -e "$obsolete_dir" ]; then
          echo "zed-mcp: trashing obsolete config dir ${name}"
          if command -v gio >/dev/null 2>&1; then
            if command_output=$(gio trash "$obsolete_dir" 2>&1); then
              printf '%s\n' "$command_output" | sed 's/^/  /'
            else
              printf '%s\n' "$command_output" | sed 's/^/  /'
              echo "zed-mcp: failed to trash $obsolete_dir (will retry next switch)"
            fi
          else
            echo "zed-mcp: gio not available; leave $obsolete_dir for manual trash"
          fi
        fi
      '') obsoleteSharedServers}
    '';

  mkCursorObsoleteRemovalActivation =
    {
      mcpFile,
      cliConfigFile,
    }:
    ''
      ${mkJsonObsoleteRemovalActivation {
        jsonFile = mcpFile;
        jqFilter = ''
          (.mcpServers //= {}) |
          reduce $obsolete[] as $name (.;
            del(.mcpServers[$name]))
        '';
      }}
      ${mkJsonObsoleteRemovalActivation {
        jsonFile = cliConfigFile;
        jqFilter = ''
          if .permissions.allow? then
            .permissions.allow |= map(
              select(. as $entry |
                ([ $obsolete[] as $name |
                  $entry | startswith("Mcp(" + $name + ":")
                ] | any | not)
              )
            )
          else
            .
          end
        '';
      }}
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
    mkClaudeObsoleteRemovalActivation
    mkClaudeObsoletePluginRemovalActivation
    mkClaudeObsoleteFileRemovalActivation
    mkOmpObsoletePluginRemovalActivation
    mkNpmGlobalObsoleteRemovalActivation
    mkZedObsoleteRemovalActivation
    mkCursorObsoleteRemovalActivation
    toZedContextServers
    obsoleteSharedServers
    obsoleteClaudePlugins
    obsoleteClaudeMarketplaces
    obsoleteClaudeFiles
    obsoleteOmpPlugins
    obsoleteNpmGlobalPackages
    needsSharedServerMaintenance
    ;
}
