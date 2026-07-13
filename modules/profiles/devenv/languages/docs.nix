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
      markdownlint-cli2
      markdown-oxide
      marksman

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
