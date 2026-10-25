# Agents feature folder — agent CLI packages (system half) plus the HM halves:
# global config links, nono profiles, pi/omp package state, and the session
# push to mini (./session-push.nix). Skills and MCP
# registration belong to APM (./apm.nix); nono profile data lives in
# `dotfilesLib.nonoProfiles`. ./darwin.nix holds the Homebrew half; the
# `homebrew.*` namespace only exists on darwin, hence the import gate.
{
  dotfilesLib,
  isDarwin ? false,
  lib,
  ...
}@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  imports = lib.optionals isDarwin [ ./darwin.nix ];
  hm = [
    ./apm.nix
    ./dsh.nix
    ./global-config.nix
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
      opencode2
      dsh
      herdr
      claude-agent-acp
      agent-browser
      nono
      tuicr
      apm
    ])
    ++ (with pkgs; [
      kagi-cli

      # nixpkgs
      ctx7
      context7-mcp
    ])
    # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
    # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
    # tuios: session manager in the herdr/tuios trial (D2 in
    # docs/agents/session-management-plan.md), 0.11.0 through
    # parts/overlays/tuios-0-11.nix. caya takes tuios from Homebrew
    # (./darwin.nix), because no cache has the overlay's darwin build.
    ++ pkgs.lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
      pkgs.mcp-nixos
      pkgs.tuios
    ];
} args
