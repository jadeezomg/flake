# Determinate Nix 3.23 emits new activity types (10113, for OTel traces).
# nom 2.2.0 cannot parse them and prints a ParseNixJSONMessageError for each
# event, which floods `nh` output. The build itself still runs.
#
# Applies upstream PR #321, which maps unknown activity and result types to
# Unknown and does not fail.
# https://github.com/maralorn/nix-output-monitor/issues/320
# https://github.com/maralorn/nix-output-monitor/pull/321
#
# Verified 2026-10-10 against nom 2.2.0 and Determinate Nix 3.23.1.
{
  expiry,
  lib,
}:
_final: prev: {
  nix-output-monitor =
    expiry.recheckWhen
      {
        stale = lib.versionAtLeast prev.nix-output-monitor.version "2.2.1";
        reason = "nix-output-monitor reached 2.2.1 (PR #321 applied at 2.2.0); check whether the release includes PR #321 and drop the overlay if it does.";
      }
      (
        prev.nix-output-monitor.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (prev.fetchpatch {
              name = "nom-unknown-activity-types.patch";
              url = "https://github.com/maralorn/nix-output-monitor/commit/3c2ae037013e840046ed9785c4da82aa1c628872.patch";
              relative = "nix-output-monitor";
              hash = "sha256-kPbn680q76cor/qZz+pSkUTAR+U6XRDroQExvVX7XhQ=";
            })
            (prev.fetchpatch {
              name = "nom-unknown-result-types.patch";
              url = "https://github.com/maralorn/nix-output-monitor/commit/202f940f96360548dedfb3b9234f6f6f08a9a2ba.patch";
              relative = "nix-output-monitor";
              hash = "sha256-87wL4BRGPxaiKwZ1uoUo26cdfOuTHwyEI7vThG8aMOs=";
            })
          ];
        })
      );
}
