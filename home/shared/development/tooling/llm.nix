{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # docs CLI
    (pkgs.callPackage ../../../../packages/context7 {})

    # Kagi search/summarizer via session token (unofficial)
    (pkgs.callPackage ../../../../packages/kagi-ken-cli {})
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
