# open-webui 0.11.4 imports opentelemetry.instrumentation.system_metrics when
# ENABLE_OTEL is on (utils/telemetry/instrumentors.py). nixpkgs does not list
# that package in its dependencies, so the service exits at startup with
# ModuleNotFoundError. mini turns OTel on in hosts/mini/services/tracing.nix.
#
# open-webui is unfree and not in the binary cache, so mini builds it locally
# in any case. This overlay adds no extra build cost.
#
# Verified 2026-10-11 against open-webui 0.11.4 on mini.
{
  expiry,
  lib,
}:
_final: prev: {
  open-webui =
    expiry.expireWhen
      {
        fixed = lib.any (
          d: (d.pname or "") == "opentelemetry-instrumentation-system-metrics"
        ) prev.open-webui.dependencies;
        reason = "nixpkgs open-webui now lists opentelemetry-instrumentation-system-metrics.";
        fallback = prev.open-webui;
      }
      (
        prev.open-webui.overridePythonAttrs (old: {
          dependencies = old.dependencies ++ [
            prev.python3Packages.opentelemetry-instrumentation-system-metrics
          ];
        })
      );
}
