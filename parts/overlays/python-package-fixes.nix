# Temporary Python package fixes for nixpkgs snapshots where dependency bounds
# or upstream tests lag newer transitive dependencies.
_final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_python-final: python-prev: {
      jedi-language-server = python-prev.jedi-language-server.overridePythonAttrs (old: {
        # 0.46.0 caps jedi at <0.20, while this nixpkgs snapshot already ships
        # jedi 0.20.0. Keep the package buildable until nixpkgs updates either
        # jedi-language-server or its metadata.
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "jedi" ];
      });

      pipx = python-prev.pipx.overridePythonAttrs (old: {
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
      });

      # Upstream installs the distribution as `ct3` (Cheetah3 is taken on PyPI).
      # nixpkgs still sets pname=cheetah3, so pythonMetadataCheckPhase fails with
      # PackageNotFoundError for cheetah3. Keep the Nix attribute as cheetah3 for
      # sabnzbd/sickgear until https://github.com/NixOS/nixpkgs/pull/545346 lands.
      cheetah3 = python-prev.cheetah3.overridePythonAttrs (_old: {
        pname = "ct3";
      });

      # setup.cfg reads version via `attr: nftables.NFTABLES_VERSION`, but upstream
      # hardcodes NFTABLES_VERSION = "0.1" while the derivation inherits the C
      # library version (1.1.6). pythonMetadataCheckPhase fails and takes
      # firewalld with it. Mirror https://github.com/NixOS/nixpkgs/pull/545471.
      nftables = python-prev.nftables.overridePythonAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace "src/nftables.py" \
            --replace-fail 'NFTABLES_VERSION = "0.1"' 'NFTABLES_VERSION = "${old.version}"'
        '';
      });
    })
  ];
}
