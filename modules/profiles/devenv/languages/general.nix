{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "general"
  ];
  packages =
    pkgs: with pkgs; [
      devenv # Reproducible dev shells
      tree-sitter # Parser generator
      just-lsp # Build/recipe runner LSP
    ];
} args
