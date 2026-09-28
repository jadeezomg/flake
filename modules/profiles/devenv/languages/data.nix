{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "data"
  ];
  packages =
    pkgs: with pkgs; [
      # YAML
      yaml-language-server

      # TOML
      taplo

      # XML
      lemminx

      # SQL
      sqlite
      sqls
    ];
} args
