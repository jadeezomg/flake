{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.general;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      devenv # Reproducible dev shells
      graphviz # Graph visualization
      prettier # Fallback prettier
      prettierd # Prettier running as a daemon
      rlwrap # CommonLisp REPL helper
      socat # CommonLisp networking glue
      tree-sitter # Parser generator
      just-lsp # Build/recipe runner LSP
    ];
  };
}
