# Send OpenTelemetry traces of every Nix command (client and daemon) to Tempo
# on mini (hosts/mini/services/tracing.nix) over the tailnet.
#
# If mini is not reachable (no tailnet), Nix prints one warning per process and
# continues. Darwin (caya) has no tailnet and no setting here. It uses a local
# otel-desktop-viewer on demand (see the nix-tracing skill).
_: {
  nix.settings = {
    otlp = true;
    otlp-endpoint = "http://mini:4318";
  };
}
