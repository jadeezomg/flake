{
  pkgs,
  inputs',
  ...
}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # docs CLI
    inputs'.self.packages.context7
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
