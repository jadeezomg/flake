# Declarative pi packages — written into ~/.pi/agent/settings.json so pi's
# own resolver (dist/core/package-manager.js `packageManager.resolve()`) installs
# anything missing on next launch. We don't run `pi install` ourselves; pi does
# it lazily when needed.
#
# Spec format (anything `pi install` would accept):
#   "npm:@scope/name"             — latest from npm
#   "npm:@scope/name@1.2.3"       — pinned
#   "git:github.com/user/repo"    — latest HEAD
#   "git:github.com/user/repo@v1" — tag / branch / commit
#
# Other settings.json fields (defaultProvider, defaultModel, lastChangelogVersion,
# …) are pi's user state. The `jq` merge preserves them — we only own `.packages`.
#
# See: https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#pi-packages
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;

  packages = [
    "npm:pi-agent-browser-native"
    "npm:pi-markdown-preview"
    "npm:pi-openrouter-realtime"
    "npm:pi-connect"
    "npm:pi-mcp-adapter"
  ];

  settingsDir = "${homeDir}/.pi/agent";
  settingsPath = "${settingsDir}/settings.json";

  esc = lib.escapeShellArg;
in
  lib.mkIf (osConfig.dotfiles.profiles.devenv.llm.agents.enable or false) {
    home.activation.piPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils]}:$PATH
      mkdir -p ${esc settingsDir}
      if ! jq -e . ${esc settingsPath} >/dev/null 2>&1; then
        printf '%s\n' '{}' >${esc settingsPath}
      fi
      tmp=$(mktemp)
      jq --argjson pkgs ${esc (builtins.toJSON packages)} \
        '.packages = $pkgs' ${esc settingsPath} >"$tmp" && mv "$tmp" ${esc settingsPath}
    '';
  }
