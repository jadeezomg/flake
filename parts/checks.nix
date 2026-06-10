# Flake checks + formatter. Eval-level test suites live under `tests/`;
# each check asserts at import time and materialises as a trivial derivation.
_: {
  perSystem = {pkgs, ...}: {
    checks.mcp-servers = let
      testPassed = import ../tests/mcp-servers.nix {lib = pkgs.lib;};
    in
      assert testPassed;
        pkgs.runCommand "mcp-servers-tests" {} ''
          touch "$out"
        '';

    formatter = pkgs.alejandra;
  };
}
