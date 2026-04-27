# https://github.com/mksglu/context-mode — Pi loads MCP from ./context-mode/mcp-servers.json
# symlinked live under ~/.pi (see dotfiles.flakeRoot).
#
# Do not symlink ~/.claude/settings.json: it holds other Claude Code keys — merge the
# `mcpServers.context-mode` entry from mcp-servers.json into your settings by hand once.
{
  config,
  lib,
  osConfig,
  ...
}: let
  inherit (import ../../../../lib/home/live-xdg-symlinks.nix {inherit config;}) mkLiveSymlink;
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;
  mcpServersJson = "${config.dotfiles.flakeRoot}/home/shared/development/tooling/context-mode/mcp-servers.json";
in
  lib.mkIf agentsEnabled {
    home.file.".pi/settings/mcp.json" = mkLiveSymlink mcpServersJson;
  }
