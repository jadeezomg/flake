{
  config,
  lib,
  pkgs,
  pkgs-small,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.agents;
  nonoAgents = import ../../../../lib/nono-profiles.nix {inherit pkgs pkgs-small;};
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      nonoAgents.agentPackages
      ++ (with pkgs; [
        goose-cli
        codex
        codex-acp
        # Profiles installed by home/shared/development/tooling/nono-profiles.nix.
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
