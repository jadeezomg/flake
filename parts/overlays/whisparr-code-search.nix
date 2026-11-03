# Whisparr 3.6.5 builds scene queries only from title/studio/date settings.
# Releases named by performer + scene code (for example
# "Jasmine.Santanna...OB278") contain neither the studio nor the date, and the
# full StashDB title may include a parenthetical the release omits, so none of
# those queries match. This patch adds the scene code as an additional query
# title, but only for interactive search. Automatic search is left alone: one
# code can name more than one scene, so a human must verify and grab.
#
# The release titles often parse as unknown movies, so the interactive rows
# appear rejected. Their confirm-grab path still works because the UI sends the
# movieId from the search payload. The upstream source is fixed to the 3.6.5
# release line; a Whisparr 4 bump may rewrite the search service, so the guard
# drops the patch and asks for a rebase instead of failing the build.
#
# Verified 2026-11-03 against whisparr 3.6.5-release.1886.
{
  expiry,
  lib,
  system,
}:
let
  isLinux = builtins.match ".*-linux" system != null;
in
_final: prev:
if !isLinux || !(prev ? whisparr_3) then
  { }
else
  {
    whisparr_3 =
      expiry.expireWhen
        {
          fixed = lib.versionAtLeast prev.whisparr_3.version "4";
          reason = "Whisparr reached 4; check whether interactive code search is built in, then rebase or drop parts/overlays/whisparr-code-search.patch.";
          fallback = prev.whisparr_3;
        }
        (
          prev.whisparr_3.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./whisparr-code-search.patch ];
          })
        );
  }
