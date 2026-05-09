{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.agents;
  nonoAgents = import ../../../../../lib/nono-profiles.nix {inherit pkgs;};
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      nonoAgents.agentPackages
      ++ (with pkgs; [
        goose-cli
        codex
        codex-acp
        # Sandboxing primitive for the agents above. Profiles in
        # ~/.config/nono/profiles/ installed by home/shared/development/tooling/nono-profiles.nix.
        nono

        # Docs / search / knowledge plumbing (local flake packages, surfaced
        # via parts/overlays/local-packages.nix)
        context7
        kagi-ken
        kagi-ken-cli
        mcp-nixos
        agent-browser
      ]);
  };
}
