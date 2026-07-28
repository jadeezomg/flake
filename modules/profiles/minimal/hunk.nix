# hunk — TUI diff viewer (`pkgs.llm-agents.hunk`). Upstream HM module lives in
# the package source until it lands in home-manager.
{ pkgs, ... }:
{
  imports = [ (import "${pkgs.llm-agents.hunk.src}/nix/home-manager.nix") ];

  programs.hunk = {
    enable = true;
    package = pkgs.llm-agents.hunk;
    enableGitIntegration = true;
    settings = {
      theme = "auto";
      mode = "split";
      line_numbers = true;
      transparent_background = true;
    };
  };
}
