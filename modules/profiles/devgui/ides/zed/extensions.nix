{ ... }: {
  programs.zed-editor = {
    extensions = [
      "nix"
      "nu"
      "html"
      "toml"
      "dockerfile"
      "git-firefly"
      "sql"
      "latex"
      "make"
      "just"
      "graphql"
      "lua"
      "ini"
      "java"
      "csv"
      "ruff"
      "pylsp"
      "rainbow-csv"
      "env"
      "github-actions"
      "kdl"
      "biome"
      "xml"
      "comment"
    ];
  };
}
