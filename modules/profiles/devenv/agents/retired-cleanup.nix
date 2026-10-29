# One-time cleanups for tools that left the flake. Each step removes what the
# tool left on a host and does nothing once it is gone. Delete a step after
# desktop, framework, mini, and caya have each switched once.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # opencode left on 2026-10-29. Its state folders go to the trash. The session
  # push had archived the sessions of the Linux hosts on mini. caya has no
  # session push, so its sessions stay only in its trash. The push staged only
  # opencode's database in ~/.cache/agent-session-push.
  opencodeDirs = map (dir: "${home}/${dir}") [
    ".config/opencode"
    ".local/share/opencode"
    ".cache/opencode"
    ".local/state/opencode"
    ".cache/agent-session-push"
  ];

  trash =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ''mv "$d" "${home}/.Trash/$(basename "$d")-$(date +%s)"''
    else
      ''${lib.getBin pkgs.glib}/bin/gio trash "$d"'';

  # The openwork MCP server left on 2026-10-29. APM dropped it from its lock
  # but keeps it in ~/.claude.json, and omp has its own ~/.omp/agent/mcp.json,
  # which nothing manages. `claude mcp remove` edits ~/.claude.json with Claude
  # Code's own locking, because a running session also writes that file.
  jq = "${pkgs.jq}/bin/jq";
  # No session hooks for these maintenance runs (see claudeNoHooks in ./apm.nix).
  claudeNoHooks = pkgs.writeText "claude-no-hooks.json" (builtins.toJSON { disableAllHooks = true; });
  claude = "${pkgs.llm-agents.claude-code}/bin/claude --settings ${claudeNoHooks}";
  claudeJson = "${home}/.claude.json";
  ompMcp = "${home}/.omp/agent/mcp.json";

  # The global mattpocock-skills plugin left on 2026-10-29. Repos that want
  # those skills install them with their own project apm.yml. omp loads every
  # installed Claude plugin that `enabledPlugins` does not set to false, so the
  # plugin and its marketplace must go.
  installedPlugins = "${home}/.claude/plugins/installed_plugins.json";
  knownMarketplaces = "${home}/.claude/plugins/known_marketplaces.json";
in
{
  home.activation.retiredCleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for d in ${lib.escapeShellArgs opencodeDirs}; do
      if [ -e "$d" ]; then
        $DRY_RUN_CMD ${trash} || echo "cleanup: could not move $d to the trash"
      fi
    done

    if ${jq} -e '.mcpServers.openwork' ${lib.escapeShellArg claudeJson} >/dev/null 2>&1; then
      $DRY_RUN_CMD ${claude} mcp remove openwork -s user >/dev/null \
        || echo "cleanup: could not remove openwork from ~/.claude.json"
    fi
    # `tee` writes into the existing file, so its mode stays as it is.
    if ${jq} -e '.mcpServers.openwork' ${lib.escapeShellArg ompMcp} >/dev/null 2>&1; then
      if new=$(${jq} 'del(.mcpServers.openwork)' ${lib.escapeShellArg ompMcp}); then
        $DRY_RUN_CMD tee ${lib.escapeShellArg ompMcp} <<<"$new" >/dev/null
      else
        echo "cleanup: could not remove openwork from ~/.omp/agent/mcp.json"
      fi
    fi

    if ${jq} -e '.plugins["mattpocock-skills@mattpocock"]' ${lib.escapeShellArg installedPlugins} >/dev/null 2>&1; then
      $DRY_RUN_CMD ${claude} plugin uninstall mattpocock-skills@mattpocock -s user >/dev/null \
        || echo "cleanup: could not uninstall mattpocock-skills"
    fi
    if ${jq} -e '.mattpocock' ${lib.escapeShellArg knownMarketplaces} >/dev/null 2>&1; then
      $DRY_RUN_CMD ${claude} plugin marketplace remove mattpocock >/dev/null \
        || echo "cleanup: could not remove the mattpocock marketplace"
    fi
  '';
}
