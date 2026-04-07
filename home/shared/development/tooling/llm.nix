{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
