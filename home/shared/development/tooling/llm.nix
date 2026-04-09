{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # docs CLI
    (pkgs.callPackage ../../../../packages/context7 {})
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
