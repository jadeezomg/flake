# Determinate Nix 3.23 adds activity type 10113 (`actStringly`) for its
# OpenTelemetry spans. nom 2.2.0 stops parsing at every activity type that it
# does not know and prints a ParseNixJSONMessageError line for each one.
# Nix continues and nom exits 0, so the errors are only noise.
#
# This overlay maps unknown activity types to nom's existing UnknownType.
# Upstream PR #321 adds a new constructor for the same result.
# https://github.com/maralorn/nix-output-monitor/issues/320
# https://github.com/maralorn/nix-output-monitor/pull/321
#
# nh wraps nom through a symlinkJoin, so only nom is rebuilt.
#
# Verified 2026-10-10 with nom 2.2.0 and Determinate Nix 3.23.1.
{ expiry, lib }:
_final: prev: {
  nix-output-monitor =
    expiry.recheckWhen
      {
        stale = lib.versionOlder "2.2.0" prev.nix-output-monitor.version;
        reason = "nix-output-monitor is newer than 2.2.0; check if it accepts unknown activity types (issue #320) and remove this overlay if it does.";
      }
      (
        prev.nix-output-monitor.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace lib/NOM/Parser/JSON.hs \
              --replace-fail \
                'other -> fail ("invalid activity type: " <> show other)' \
                '_ -> pure UnknownType'
          '';
        })
      );
}
