{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "web"
  ];
  packages =
    pkgs: with pkgs; [
      # JavaScript runtime
      nodejs_24
      bun

      # TypeScript
      typescript
      yarn-berry
      typescript-language-server
      biome

      # GraphQL
      graphql-language-service-cli
    ];
} args
