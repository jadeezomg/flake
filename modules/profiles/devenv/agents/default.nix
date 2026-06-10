# Agents feature folder — agent CLI packages (system half) plus the HM
# halves: skills install, nono profiles, pi/omp/claude MCP config. All HM
# modules are pushed via sharedModules when the profile is on; the MCP files
# keep their internal registry logic (./mcp-servers.nix is a helper they
# import, not a module).
{
  config,
  lib,
  pkgs,
  pkgs-small,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.agents;
  nonoAgents = import ../../../../lib/nono-profiles.nix {inherit pkgs pkgs-small;};
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ./skills.nix
      ./global-config.nix
      ./agents-cli.nix
      ./nono-profiles.nix
      ./pi-packages.nix
      ./pi-mcp.nix
      ./omp-mcp.nix
      ./claude-mcp.nix
    ];

    environment.systemPackages =
      nonoAgents.agentPackages
      ++ (with pkgs; [
        goose-cli
        codex
        codex-acp
        # Profiles installed by ./nono-profiles.nix (HM half).
        nono

        # Local flake packages from parts/overlays/local-packages.nix.
        context7
        kagi-cli
        agent-browser
      ])
      # mcp-nixos pulls python3.lupa → luajit_2_0, which nixpkgs 26.05 marks
      # unsupported on aarch64-darwin. Drop it on Darwin until fixed upstream.
      ++ lib.optionals (!pkgs.stdenv.isDarwin) [pkgs.mcp-nixos];
  };
}
