# nixpkgs moved python3Packages.mcp to 2.x (2026-10-16) and marked posthog
# broken against it: meta.broken = versionAtLeast mcp.version "2". posthog
# only uses mcp in its tests (nativeCheckInputs), so it builds against
# python3Packages.mcp_1 (1.29.0), which nixpkgs added for this case.
# open-webui (mini, services/llm/open-webui.nix) depends on posthog, and the
# broken flag stops evaluation of the whole system.
#
# Verified 2026-10-25 against nixpkgs 3ec6363 (posthog 7.71.0, mcp 2.2.0).
{
  expiry,
}:
_final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      posthog =
        expiry.expireWhen
          {
            fixed = !(pyprev.posthog.meta.broken or false);
            reason = "nixpkgs no longer marks posthog broken against its own mcp.";
            fallback = pyprev.posthog;
          }
          (
            pyprev.posthog.override {
              mcp = pyfinal.mcp_1;
            }
          );
    })
  ];
}
