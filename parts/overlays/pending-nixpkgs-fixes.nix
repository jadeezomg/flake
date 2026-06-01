# Temporary overrides for nixpkgs packages pending an upstream PR merge.
# Each entry should reference the PR URL so it can be removed once merged.
_final: prev: {
  # TODO remove after fix is upstreamed
  # https://github.com/NixOS/nixpkgs/pull/525720
  # firefoxpwa-unwrapped postInstall misses `mkdir $out/lib/firefoxpwa`,
  # causing the wrapper to fail when it tries to write `is-packaged-app`.
  firefoxpwa-unwrapped = prev.firefoxpwa-unwrapped.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        mkdir $out/lib/firefoxpwa
      '';
  });
}
