# Showtime 50.0 freezes when a new video is opened while one plays. Playsink
# rebuilds the video chain, holds its lock, and waits for the GTK main thread
# (gtk4paintablesink). If an MPRIS client polls Showtime at that moment, the
# MPRIS GetAll handler calls play.get_volume() on the main thread, which needs
# the same playsink lock. Both sides wait forever. Noctalia polls MPRIS every
# ~50 s, so this hits on almost every drag-and-drop.
#
# The window already caches the volume in its `volume` property. This overlay
# makes the MPRIS handler read that cache instead of the pipeline.
#
# Verified 2026-09-27 from a core dump of showtime 50.0 (GStreamer 1.28.6,
# gst-plugins-rs 0.15.3) on x86_64-linux.
{
  expiry,
  lib,
  system,
}:
let
  isLinux = builtins.match ".*-linux" system != null;
in
_final: prev:
if !isLinux then
  { }
else
  {
    showtime =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.showtime.version "51";
          reason = "showtime reached 51; retest drag-and-drop while a video plays and drop the MPRIS volume patch if fixed.";
        }
        (
          prev.showtime.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace showtime/mpris.py \
                --replace-fail \
                  'volume = self.play.get_volume() if self.play else 0.0' \
                  'volume = self.win.volume if self.win else 0.0'
            '';
          })
        );
  }
