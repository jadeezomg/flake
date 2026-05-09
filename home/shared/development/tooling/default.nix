{...}: {
  # cloud, databases, tools moved to dotfiles.profiles.devenv.* in P3a.
  # This dir keeps llm.nix because it still ships the opencode HM widget.
  imports = [
    ./llm.nix
    ./pi-packages.nix
    ./pi-mcp.nix
    ./claude-mcp.nix
    ./nono-profiles.nix
  ];
}
