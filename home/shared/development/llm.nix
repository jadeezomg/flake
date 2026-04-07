{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Gui / Server
    # lm-studio  # Available via Homebrew on Darwin (lm-studio cask)
    # LLM Agent
    opencode
    claude-code
  ];

  # programs.opencode = {
  #   enable = true;
  #   package = pkgs.opencode;
  # };
}
