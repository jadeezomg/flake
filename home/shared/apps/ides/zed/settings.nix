{
  lib,
  claude-agent-acp-fork,
  ...
}: let
  settingsModules = [
    (import ./settings/appearance.nix {inherit lib;})
    (import ./settings/git.nix {})
    (import ./settings/panels.nix {})
    (import ./settings/terminal.nix {inherit lib;})
    (import ./settings/behavior.nix {})
    (import ./settings/agents-and-mcp.nix {inherit claude-agent-acp-fork;})
    (import ./settings/editor.nix {})
    (import ./settings/chrome.nix {})
  ];
in {
  programs.zed-editor = {
    userSettings = lib.foldl' lib.recursiveUpdate {} settingsModules;
  };
}
