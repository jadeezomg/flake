{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # docs CLI
    (pkgs.callPackage ../../../../packages/context7 {})

    # Kagi search/summarizer via session token (unofficial)
    (pkgs.callPackage ../../../../packages/kagi-ken-cli {})

    # Code knowledge graph + MCP (PyPI)
    (pkgs.callPackage ../../../../packages/code-review-graph {})

    # Pi coding agent — npm release ahead of nixpkgs
    (pkgs.callPackage ../../../../packages/pi-coding-agent {})
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
