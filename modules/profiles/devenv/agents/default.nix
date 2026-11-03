# Agents feature folder — agent CLI packages (system half) plus the HM halves:
# the agent-review command (./agent-review.nix), global config links, herdr
# configuration and plugins (./herdr-config.nix, ./herdr-plugins.nix), nono profiles, pi/omp package state, the
# cleanup of retired tools (./retired-cleanup.nix), the session push to
# mini (./session-push.nix), and the cross-host resume with its tv channel (./session-resume.nix). Skills and MCP registration belong to APM (./apm.nix);
# nono profile data lives in `dotfilesLib.nonoProfiles`.
{
  dotfilesLib,
  lib,
  pkgs-small,
  ...
}@args:
let
  inherit (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/agents/default.nix")
    expireWhen
    ;
in
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # A leaf of its own: it also has a darwin-only system part.
  imports = [ ./retired-cleanup.nix ];
  hm = [
    ./agent-review.nix
    ./agentsview.nix
    ./apm.nix
    ./dsh.nix
    ./global-config.nix
    ./herdr-config.nix
    ./herdr-plugins.nix
    ./nono-agent.nix
    ./nono-profiles.nix
    ./pi-packages.nix
    ./session-push.nix
    ./session-resume.nix
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
      agentsview
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
      # docs/agents/session-management-plan.md). Our nixos-unstable lock has
      # 0.11.1. nixos-unstable-small already has 0.12.0.
      (expireWhen {
        fixed = lib.versionAtLeast pkgs.tuios.version "0.12.0";
        reason = "nixos-unstable now ships tuios >= 0.12.0.";
        fallback = pkgs.tuios;
      } pkgs-small.tuios)
      # herdr-core (`hc`): runs terminals and agents headless and keeps them
      # alive. nixpkgs#581031 reached nixos-unstable-small first.
      (expireWhen {
        fixed = pkgs ? herdr-core;
        reason = "nixos-unstable now ships herdr-core (nixpkgs#581031).";
        fallback = pkgs.herdr-core;
      } pkgs-small.herdr-core)
    ])
    # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
    # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
    ++ pkgs.lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ pkgs.mcp-nixos ];
} args
