# Send OpenTelemetry traces of every Nix command (client and daemon) to Tempo
# on mini (hosts/mini/services/tracing.nix) over the tailnet.
#
# The settings are in a separate file, not in nix.settings. NixOS validates the
# generated nix.conf in the build sandbox with `nix config show` and fails on
# every warning or error line. With otlp set there, that command tries to export
# a trace, cannot resolve mini, and fails the build. Nix skips a missing
# `!include` without a message, and the sandbox has no /etc/nix/otlp.conf.
#
# If mini is not reachable (no tailnet), Nix prints one warning per process and
# continues. Darwin (caya) has no tailnet and no setting here. It uses a local
# otel-desktop-viewer on demand (see the nix-tracing skill).
_: {
  environment.etc."nix/otlp.conf".text = ''
    otlp = true
    otlp-endpoint = http://mini:4318
  '';
  nix.extraOptions = "!include /etc/nix/otlp.conf";
}
