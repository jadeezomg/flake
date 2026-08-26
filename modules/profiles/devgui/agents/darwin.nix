# Darwin-only leaf of devgui.agents. openwork ships as an Electron app with no
# nixpkgs package, so it comes from the autobumped homebrew/cask instead of a
# hash-pinned local package. The openwork MCP endpoint that the app pairs with
# is registered for every agent in lib/mcp-servers.nix.
{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.devgui.agents;
in
{
  homebrew = lib.mkIf cfg.enable {
    # mkDefault so the work profile keeps ownership of `enable` on caya, and
    # devgui alone still turns homebrew on for a darwin host without work.
    enable = lib.mkDefault true;

    casks = [
      "openwork" # Open-source desktop agent workspace (powered by opencode)
    ];
  };
}
