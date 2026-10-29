# herdr plugins from the flake. herdr keeps its plugin registry in
# ~/.config/herdr/plugins.json and writes to that file itself, so the flake
# cannot own it. Each switch links the plugin folders in `plugins` with
# `herdr plugin link`, then unlinks every plugin that is linked from
# /nix/store but is no longer in `plugins`.
#
# Checked with herdr 0.9.5 (2026-10-28):
#   - `link` accepts a read-only folder, so a store path works.
#   - Linking the same path again changes nothing. Linking the same plugin id
#     from a new path replaces the entry, so a package update needs no unlink.
#   - `link` does not run the manifest's [[build]] commands. The package must
#     contain the built plugin folder.
#
# Plugins that you link by hand from outside /nix/store, and plugins from
# `herdr plugin install`, stay as they are. An unlink keeps the plugin's config
# and state folders, the same as `herdr plugin uninstall`.
{
  lib,
  pkgs,
  ...
}:
let
  herdr = "${pkgs.llm-agents.herdr}/bin/herdr";

  # Upstream's plugin (herdr-plugin/ in zenbu-labs/terminal-browser) installs
  # the binary with `curl | bash` in its [[build]] step and finds it on PATH.
  # Here the binary comes from llm-agents, so this manifest calls it by its store
  # path and has no build step. Plugin and action ids are the same as upstream.
  # The herdr server keeps the environment from its start, so the action sets
  # the telemetry opt-out of lib/shells/env-data.nix itself.
  terminalBrowser = pkgs.llm-agents.terminal-browser;
  terminalBrowserManifest = (pkgs.formats.toml { }).generate "herdr-plugin.toml" {
    id = "zenbu-labs.terminal-browser";
    name = "Terminal Browser";
    inherit (terminalBrowser) version;
    min_herdr_version = "0.8.2";
    description = "Open a browser inside herdr";
    platforms = [
      "linux"
      "macos"
    ];
    actions = [
      {
        id = "open-split";
        title = "Open terminal-browser (right split)";
        description = "Split the focused pane and open terminal-browser in it";
        contexts = [ "global" ];
        command = [
          "${pkgs.coreutils}/bin/env"
          "TERMINAL_BROWSER_NO_TELEMETRY=1"
          (lib.getExe terminalBrowser)
          "open"
          "--split"
          "right"
        ];
      }
    ];
  };
  terminalBrowserPlugin = pkgs.runCommand "herdr-plugin-terminal-browser" { } ''
    install -Dm644 ${terminalBrowserManifest} $out/herdr-plugin.toml
  '';

  plugins = [
    "${pkgs.herdr-sidebar}/share/herdr/plugins/herdr-sidebar"
    "${terminalBrowserPlugin}"
  ];
in
{
  # Non-fatal: a failed link must not fail the switch. The next switch retries.
  home.activation.herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in ${lib.escapeShellArgs plugins}; do
      $DRY_RUN_CMD ${herdr} plugin link "$dir" >/dev/null \
        || echo "herdr: plugin link $dir failed (will retry next switch)"
    done
    ${herdr} plugin list --json 2>/dev/null \
      | ${pkgs.jq}/bin/jq -r --args '
          .result.plugins[]
          | select(.source.kind == "local" and (.plugin_root | startswith("/nix/store/")))
          | select(.plugin_root | IN($ARGS.positional[]) | not)
          | .plugin_id
        ' ${lib.escapeShellArgs plugins} \
      | while read -r id; do
          $DRY_RUN_CMD ${herdr} plugin unlink "$id" >/dev/null \
            || echo "herdr: plugin unlink $id failed (will retry next switch)"
        done
  '';
}
