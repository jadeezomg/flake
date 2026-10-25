# nixpkgs moved python3Packages.mcp to 2.x (2026-10-16). open-webui 0.12.3
# still imports mcp 1 API (`streamablehttp_client` from
# mcp.client.streamable_http), and nixpkgs relaxes all its dependency bounds,
# so it builds but exits at startup with ImportError. This overlay gives
# open-webui a Python package set where mcp is mcp_1 (1.29.0), so its whole
# dependency tree agrees on mcp 1.
#
# Applied before open-webui-otel-system-metrics: that overlay extends this
# result with overridePythonAttrs.
#
# Verified 2026-10-25 on mini against nixpkgs 3ec6363 (open-webui 0.12.3,
# mcp 2.2.0).
{
  expiry,
  lib,
}:
_final: prev: {
  open-webui =
    let
      python = prev.python3.override {
        self = python;
        packageOverrides = _pyfinal: pyprev: { mcp = pyprev.mcp_1; };
      };
      usesMcp1 = lib.any (
        d: (d.pname or "") == "mcp" && lib.versionOlder d.version "2"
      ) prev.open-webui.dependencies;
    in
    expiry.recheckWhen
      {
        stale = lib.versionAtLeast prev.open-webui.version "0.13";
        reason = "open-webui reached 0.13 (verified needed at 0.12.3); check whether it imports mcp 2 now.";
      }
      (
        expiry.expireWhen {
          fixed = usesMcp1;
          reason = "nixpkgs open-webui now depends on mcp 1 itself.";
          fallback = prev.open-webui;
        } (prev.open-webui.override { python3Packages = python.pkgs; })
      );
}
