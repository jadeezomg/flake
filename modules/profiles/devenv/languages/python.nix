{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [
    "devenv"
    "languages"
    "python"
  ];
  packages =
    pkgs: with pkgs; [
      uv # rustic Python package manager
      ty # rustic type checker
      ruff # Fast Python formatter/linter
      # Plain interpreter for ad-hoc scripts. Project deps live in uv projects
      # (scripts/pyproject.toml carries lz4 and rich); `uv tool` replaces pipx.
      python3
    ];
} args
