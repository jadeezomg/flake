# nixpkgs moved python3Packages.mcp to 2.x (2026-10-16) and marked
# fastmcp-slim broken against it: meta.broken = versionAtLeast mcp.version "2".
# nixpkgs also added python3Packages.mcp_1 (1.29.0) for packages that still
# need mcp 1, so fastmcp-slim builds against that. mcp-nixos (devenv agents
# profile) pulls fastmcp-slim in through fastmcp, and the broken flag stops
# evaluation of the whole system.
#
# Verified 2026-10-24 against nixpkgs 3ec6363 (fastmcp-slim 3.4.7, mcp 2.2.0).
{
  expiry,
  lib,
}:
_final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      # A package set that already uses mcp 1 (open-webui-mcp1) needs no
      # override, and its fastmcp-slim must not count as fixed upstream.
      fastmcp-slim =
        if lib.versionOlder pyfinal.mcp.version "2" then
          pyprev.fastmcp-slim
        else
          expiry.expireWhen
            {
              fixed = !(pyprev.fastmcp-slim.meta.broken or false);
              reason = "nixpkgs no longer marks fastmcp-slim broken against its own mcp.";
              fallback = pyprev.fastmcp-slim;
            }
            (
              pyprev.fastmcp-slim.override {
                mcp = pyfinal.mcp_1;
              }
            );
    })
  ];
}
