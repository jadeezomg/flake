# debugpy fails one test on darwin in the nix sandbox:
#   FAILED tests/debugpy/server/test_add_code_to_python_process.py::test_lldb_command - assert False
# The test attaches lldb to a running python process. The darwin sandbox does
# not allow that. The x86_64-linux build of the same version is in
# cache.nixos.org, but the aarch64-darwin build is not, so the fault is
# darwin-only. The vscode ms-python.python extension pulls debugpy into caya.
#
# Verified 2026-10-12 against debugpy 1.8.22 on aarch64-darwin.
{
  expiry,
  lib,
  system,
}:
let
  isDarwin = builtins.match ".*-darwin" system != null;
  test = "test_lldb_command";
in
_final: prev:
if !isDarwin then
  { }
else
  {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pyfinal: pyprev: {
        debugpy =
          expiry.expireWhen
            {
              fixed = lib.elem test (pyprev.debugpy.disabledTests or [ ]);
              reason = "nixpkgs now disables debugpy's test_lldb_command itself.";
              fallback = pyprev.debugpy;
            }
            (
              pyprev.debugpy.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [ test ];
              })
            );
      })
    ];
  }
