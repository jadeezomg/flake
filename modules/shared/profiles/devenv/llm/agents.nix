{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.agents;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Agent CLIs
      claude-code
      pi-coding-agent
      goose-cli

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
    ];
  };
}
