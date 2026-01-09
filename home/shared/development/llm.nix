{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Gui / Server
    # lmstudio
    # LLM Agent
    opencode
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
