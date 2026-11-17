# nix-update hands `nix flake metadata --json`'s `path` to nix-instantiate as
# the flake to evaluate. Determinate Nix runs this store with `lazy-trees =
# true`, which reports the store path of a dirty flake tree without
# materialising it: the path is valid in the store DB but nothing exists on
# disk. nix-instantiate then dies on the first file it reads:
#   error: opening file "/nix/store/…-source": No such file or directory
# Every `nix-update --flake <attr>` package fails this way (`just update`
# reported it for nautilus-my-computer; the rest of packages/* go through
# update.json handlers that never evaluate the flake).
#
# Ignoring a reported path that is not on disk falls back to what nix-update
# already does when metadata reports no path at all: evaluate the flake from
# the working directory, which works under both Nix implementations.
#
# Still unfixed upstream at 1.16 (checked 2026-11-15):
#   https://github.com/Mic92/nix-update/blob/main/nix_update/options.py
{
  expiry,
  lib,
}:
_final: prev: {
  nix-update =
    expiry.recheckWhen
      {
        stale = lib.versionAtLeast prev.nix-update.version "1.18";
        reason = "nix-update reached 1.18; check whether it skips reported flake store paths that do not exist.";
      }
      (
        prev.nix-update.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace nix_update/options.py \
              --replace-fail \
                'if not isinstance(path, str):' \
                'if not isinstance(path, str) or not Path(path).exists():'
          '';
        })
      );
}
