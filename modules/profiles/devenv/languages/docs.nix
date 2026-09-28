{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "docs"
  ];
  packages =
    pkgs: with pkgs; [
      # Markdown
      marksman # LSP: heading refs, TOC action, link diagnostics

      # Typst
      typst
      tinymist # Typst language server with built-in formatters

      # Diagrams
      mermaid-cli

      # Slides
      slidev-cli
    ];
} args
