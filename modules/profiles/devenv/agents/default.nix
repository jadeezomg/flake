# Agents feature folder — agent CLI packages (system half) plus the HM halves:
# global config links, global skill install, nono profiles, pi/omp package
# state, and pi/omp/claude MCP registration. Shared MCP registry logic lives in
# `dotfilesLib.mcpServers`; nono profile data lives in `dotfilesLib.nonoProfiles`.
{
  dotfilesLib,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.agents;
  agents = pkgs.llm-agents;
  nonoAgents = dotfilesLib.nonoProfiles { inherit pkgs; };
in
{
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ./skills.nix
      ./global-config.nix
      ./nono-agent.nix
      ./nono-profiles.nix
      ./pi-packages.nix
      ./pi-mcp.nix
      ./omp-mcp.nix
      ./claude-mcp.nix
      ./tuicr.nix
    ];

    environment.systemPackages =
      nonoAgents.agentPackages
      ++ (with agents; [
        codex
        codex-acp
        cursor-agent
        herdr
        openspec
        claude-agent-acp
        agent-browser
        nono
        tuicr
      ])
      ++ (with pkgs; [
        kagi-cli

        # nixpkgs
        ctx7
        context7-mcp
      ])
      # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
      # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [ pkgs.mcp-nixos ];
  };
}
