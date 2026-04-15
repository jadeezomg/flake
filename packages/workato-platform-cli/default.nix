{
  pkgs,
  lib,
}: let
  py = pkgs.python3Packages;
  # Upstream marks this broken; wheel build needs Cython in nativeBuildInputs on Python 3.13.
  dependency-injector = py.dependency-injector.overridePythonAttrs (old: {
    meta = (old.meta or {}) // {broken = false;};
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [py.cython];
    doCheck = false;
  });
in
  py.buildPythonApplication rec {
    pname = "workato-platform-cli";
    version = "1.0.6";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "workato-devs";
      repo = "workato-platform-cli";
      rev = version;
      hash = "sha256-NZ7FeIC90ILVfjwyKFJBm/MbOMR/x6xhKuGuagyfmiI=";
    };

    # Listed as a runtime dep upstream but only used for linting (not imported by the CLI).
    pythonRemoveDeps = ["ruff"];

    nativeBuildInputs = with py; [
      hatchling
      hatch-vcs
    ];

    propagatedBuildInputs = with py; [
      aiohttp
      aiohttp-retry
      asyncclick
      cbor2
      certifi
      dependency-injector
      inquirer
      keyring
      packaging
      prompt-toolkit
      pydantic
      pydantic-settings
      python-dateutil
      typing-extensions
      urllib3
    ];

    env.HATCH_VCS_PRETEND_VERSION = version;

    doCheck = false;

    meta = with lib; {
      description = "Command-line interface for the Workato platform API";
      homepage = "https://docs.workato.com/en/platform-cli.html";
      license = licenses.mit;
      mainProgram = "workato";
    };
  }
