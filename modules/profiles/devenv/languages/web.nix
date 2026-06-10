{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.web;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # JavaScript runtime
      nodejs_24
      bun

      # TypeScript
      typescript
      yarn-berry
      typescript-language-server
      biome

      # CSS / HTML
      vscode-langservers-extracted
      html-tidy
      dart-sass

      # GraphQL
      graphql-language-service-cli
    ];
  };
}
