# Temporary Python package fixes for nixpkgs snapshots where dependency bounds
# or upstream tests lag newer transitive dependencies. Each fix carries the
# condition that retires it; delete the file when the last one expires.
{ expiry, lib }:
_final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_python-final: python-prev: {
      # Upstream parametrizes with a trailing comma in argnames (`"pkg_spec,"`),
      # which newer pytest reads as multi-name parametrization and fails
      # collection of the whole file — 24 errors, before `disabledTests` filtering
      # gets a say. Verified 2026-07-31 against pipx 1.14.0 / python 3.14: the
      # unpatched build fails, and ignoring this one path is enough to pass
      # (165 passed, 7 skipped).
      pipx =
        expiry.expireWhen
          {
            fixed = lib.elem "tests/test_inject.py" (python-prev.pipx.disabledTestPaths or [ ]);
            reason = "nixpkgs already ignores tests/test_inject.py, whose collection failure is the only thing this override works around.";
            fallback = python-prev.pipx;
          }
          (
            python-prev.pipx.overridePythonAttrs (old: {
              disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
                "tests/test_inject.py"
              ];
            })
          );
    })
  ];
}
