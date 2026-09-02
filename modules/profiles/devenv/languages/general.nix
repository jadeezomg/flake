{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.devenv.languages.general;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      devenv # Reproducible dev shells
      tree-sitter # Parser generator
      just-lsp # Build/recipe runner LSP
    ];
  };
}
