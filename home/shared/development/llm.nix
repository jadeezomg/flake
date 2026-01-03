{pkgs-unstable, ...}: {
  home.packages = with pkgs-unstable; [
    # LLM Gui / Server
    # lmstudio
    # LLM Agent
    opencode
  ];

  programs.opencode = {
    enable = true;
    package = pkgs-unstable.opencode;
  };
}
