{
  dotfilesLib,
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  # User-level ~/.config/nix/nix.conf so `nix` / `nh` on Linux match
  # `modules/shared/environment.nix` before the next `switch` (needed to evaluate
  # mini + vllm-xpu, which use CA derivations). Darwin HM would require `nix.package`
  # to emit nix.conf; Determinate leaves Nix alone there.
  nix.settings.experimental-features = dotfilesLib.nixExperimentalFeatures {
    inherit lib;
    isDarwin = false;
  };
}
