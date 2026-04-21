{
  pkgs,
  lib,
}: let
  py = pkgs.python3Packages;
in
  py.buildPythonApplication rec {
    pname = "code-review-graph";
    version = "2.3.2";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "code_review_graph";
      inherit version;
      hash = "sha256-c1HWUaV5tWJDpvjzUnf9uAvvJclj2KFNZnM4yWbe6Sg=";
    };

    nativeBuildInputs = with py; [hatchling];

    propagatedBuildInputs = with py; [
      fastmcp
      mcp
      networkx
      tree-sitter
      tree-sitter-language-pack
      watchdog
    ];

    # nixpkgs ships newer majors than upstream's wheel metadata allows; runtime is compatible.
    pythonRelaxDeps = [
      "tree-sitter-language-pack"
      "watchdog"
    ];

    doCheck = false;

    meta = with lib; {
      description = "Incremental knowledge graph for token-efficient code review (MCP + Tree-sitter)";
      homepage = "https://github.com/tirth8205/code-review-graph";
      license = licenses.mit;
      mainProgram = "code-review-graph";
    };
  }
