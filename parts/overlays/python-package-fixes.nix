# Temporary Python package fixes for nixpkgs snapshots where dependency bounds
# or upstream tests lag newer transitive dependencies.
_final: prev: {
  pythonPackagesExtensions =
    (prev.pythonPackagesExtensions or [])
    ++ [
      (_python-final: python-prev: {
        jedi-language-server = python-prev.jedi-language-server.overridePythonAttrs (old: {
          # 0.46.0 caps jedi at <0.20, while this nixpkgs snapshot already ships
          # jedi 0.20.0. Keep the package buildable until nixpkgs updates either
          # jedi-language-server or its metadata.
          pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["jedi"];
        });

        pipx = python-prev.pipx.overridePythonAttrs (old: {
          # packaging changed direct-reference rendering from `name@ URL` to the
          # PEP 508 canonical `name @ URL`; these assertions are stale upstream.
          disabledTests =
            (old.disabledTests or [])
            ++ [
              "test_fix_package_name"
              "test_parse_specifier_for_metadata"
            ];
        });
      })
    ];
}
