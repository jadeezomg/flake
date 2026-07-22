# Agents feature folder — agent CLI packages (system half) plus the HM halves:
# global config links, global skill install, nono profiles, pi/omp package
# state, and pi/omp/claude MCP registration. Shared MCP registry logic lives in
# `dotfilesLib.mcpServers`; nono profile data lives in `dotfilesLib.nonoProfiles`.
{
  dotfilesLib,
  config,
  lib,
  pkgs,
  pkgs-small,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.agents;
  nonoAgents = dotfilesLib.nonoProfiles { inherit pkgs pkgs-small; };
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
    ];

    environment.systemPackages =
      nonoAgents.agentPackages
      ++ (with pkgs-small; [
        goose-cli
        codex
        codex-acp
        cursor-cli
      ])
      # Local flake packages from parts/overlays/local-packages.nix.
      ++ (with pkgs; [
        nono

        claude-agent-acp
        context7
        kagi-cli
        agent-browser
      ])
      # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
      # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [ pkgs.mcp-nixos ];
  };
}
