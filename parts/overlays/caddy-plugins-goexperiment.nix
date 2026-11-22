# caddy.withPlugins builds its source through `xcaddy`, so a plugin that pulls
# tailscale.com (mini's caddy-tailscale) also vendors go-json-experiment/json
# v0.0.0-2025-08-13. That module ships a generated alias file gated on
# `goexperiment.jsonv2`, which Go 1.27 enables by default; the stdlib aliases it
# emits (`json.SkipFunc`, `json.DiscardUnknownMembers`) were removed in that Go
# release, so compilation fails. With the experiment off, the module's own
# implementation compiles instead. Keep this until mini's caddy-tailscale pin
# moves to a tailscale that requires a Go 1.27-compatible go-json-experiment.
#
# Turning the experiment off makes Go rebuild the standard library into the
# build cache, so a caddy build costs a little more. Pinning Caddy to
# `buildGo126Module` also works, but changes the generated vendor tree and
# therefore the `hash` in mini's caddy config.
#
# Verified 2026-11-22 against caddy 2.11.9, caddy-tailscale bb080c4414ac
# (tailscale v1.90.9), Go 1.27.3, nixpkgs 2786a2a.
{
  expiry,
  lib,
}:
final: prev: {
  caddy =
    expiry.recheckWhen
      {
        stale = lib.versionAtLeast prev.caddy.version "2.12";
        reason = "caddy reached 2.12; retest the default Go builder (Go 1.27 plus the go-json-experiment v2025-08 alias file). Drop this workaround if the plugin graph resolves.";
      }
      (
        prev.caddy.overrideAttrs (prevAttrs: {
          env = (prevAttrs.env or { }) // {
            GOEXPERIMENT = "nojsonv2";
          };
        })
      );
}
