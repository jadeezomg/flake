# Agents feature folder — agent CLI packages (system half) plus the HM halves:
# the agent-review command (./agent-review.nix), global config links, herdr
# configuration and plugins (./herdr-config.nix, ./herdr-plugins.nix), nono profiles, pi/omp package state, the
# cleanup of retired tools (./retired-cleanup.nix), and the session push to
# mini (./session-push.nix). Skills and MCP registration belong to APM (./apm.nix);
# nono profile data lives in `dotfilesLib.nonoProfiles`.
{
  dotfilesLib,
  ...
}@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # A leaf of its own: it also has a darwin-only system part.
  imports = [ ./retired-cleanup.nix ];
  hm = [
    ./agent-review.nix
    ./apm.nix
    ./dsh.nix
    ./global-config.nix
    ./herdr-config.nix
    ./herdr-plugins.nix
    ./nono-agent.nix
    ./nono-profiles.nix
    ./pi-packages.nix
    ./session-push.nix
    ./tuicr.nix
  ];

  packages =
    pkgs:
    let
      agents = pkgs.llm-agents;
      nonoAgents = dotfilesLib.nonoProfiles { inherit pkgs; };
    in
    nonoAgents.agentPackages
    ++ (with agents; [
      codex
      codex-acp
      dsh
      herdr
      claude-agent-acp
      agent-browser
      terminal-browser
      nono
      tuicr
      apm
    ])
    ++ (with pkgs; [
      kagi-cli

      # nixpkgs
      ctx7
      context7-mcp
      # Session manager in the herdr/tuios trial (D2 in
      # docs/agents/session-management-plan.md).
      tuios
    ])
    # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
    # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
    ++ pkgs.lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ pkgs.mcp-nixos ];
} args
