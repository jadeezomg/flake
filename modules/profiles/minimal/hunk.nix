# hunk — TUI diff viewer (pkgs.hunk in nixpkgs). Upstream HM module lives in
# the package source until it lands in home-manager.
{ pkgs, ... }:
{
  imports = [ (import "${pkgs.hunk.src}/nix/home-manager.nix") ];

  programs.hunk = {
    enable = true;
    enableGitIntegration = true;
    settings = {
      theme = "auto";
      mode = "split";
      line_numbers = true;
      transparent_background = true;
    };
  };
}
