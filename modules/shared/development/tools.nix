{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Development tools
    gitui # Blazing fast terminal-ui for Git written in Rust
    just # Handy way to save and run project-specific commands
    mask # CLI task runner defined by a simple markdown file
    tokei # Code metrics
    uv # Python package manager
    gh # GitHub CLI
  ];
}

