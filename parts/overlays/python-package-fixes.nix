# Temporary Python package fixes for nixpkgs snapshots where dependency bounds
# or upstream tests lag newer transitive dependencies. Each fix carries the
# condition that retires it; delete the file when the last one expires.
{ expiry, lib }:
_final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_python-final: python-prev: {
      pipx =
        expiry.expireWhen
          {
            # Compound: both justifications must be gone before this can go.
            fixed =
              lib.elem "test_fix_package_name" (python-prev.pipx.disabledTests or [ ])
              && lib.elem "tests/test_inject.py" (python-prev.pipx.disabledTestPaths or [ ]);
            reason = "nixpkgs already disables the stale packaging assertions and the test_inject.py collection failure.";
            fallback = python-prev.pipx;
          }
          (
            python-prev.pipx.overridePythonAttrs (old: {
              # packaging changed direct-reference rendering from `name@ URL` to the
              # PEP 508 canonical `name @ URL`; these assertions are stale upstream.
              disabledTests = (old.disabledTests or [ ]) ++ [
                "test_fix_package_name"
                "test_parse_specifier_for_metadata"
              ];
              # Upstream parametrizes with a trailing comma in argnames
              # (`"pkg_spec,"`), which newer pytest parses as multi-name
              # parametrization and fails collection of the entire file.
              disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
                "tests/test_inject.py"
              ];
            })
          );
    })
  ];
}
