{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # docs mcp
    context7-mcp
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
