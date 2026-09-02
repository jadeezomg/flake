{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.docs;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
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
  };
}
