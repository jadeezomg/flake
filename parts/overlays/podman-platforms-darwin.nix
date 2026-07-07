# nixos-unstable snapshot b5aa0fb (2026-06-29) accidentally dropped
# aarch64-darwin/x86_64-darwin from `podman.meta.platforms`, which breaks every
# Darwin podman consumer (notably `podman-desktop`, whose install phase pulls
# podman). The platform was restored on nixpkgs master, so this is a transient
# channel regression, not a real build break (the prior snapshot built podman on
# Darwin fine). Re-add the Darwin platforms until nixos-unstable carries the fix.
# Remove this overlay once `pkgs.podman.meta.platforms` includes darwin again.
{system}: _final: prev: let
  isDarwin = builtins.match ".*-darwin" system != null;
in
  if !isDarwin
  then {}
  else {
    podman = prev.podman.overrideAttrs (old: {
      meta =
        old.meta
        // {
          platforms = old.meta.platforms ++ ["aarch64-darwin" "x86_64-darwin"];
        };
    });
  }
