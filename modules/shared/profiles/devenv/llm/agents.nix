{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.llm.agents;
in {
  config = lib.mkIf cfg.enable {
    programs.crush.enable = true;

    environment.systemPackages = with pkgs; [
      # Agent CLIs
      # opencode
      claude-code

      # Docs / search / knowledge plumbing (local flake packages, surfaced
      # via parts/overlays/local-packages.nix)
      context7
      kagi-ken
      kagi-ken-cli
      # code-review-graph
      pi-coding-agent
      agent-browser
    ];
  };
}
