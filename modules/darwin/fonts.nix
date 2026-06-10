{
  lib,
  pkgs,
  ...
}: {
  # Install every `enable = true` font from the shared catalogue
  # (home/shared/assets/fonts/fonts.nix) into /Library/Fonts/Nix Fonts.
  #
  # The Home Manager font installer is gated off on Darwin (see
  # home/shared/assets/fonts/install.nix) because HM's per-user font
  # buildEnv (~/Library/Fonts/HomeManager) fails on packages with a
  # share/fonts/woff layout. nix-darwin's fonts.packages copies only
  # ttf/ttc/otf/dfont files via rsync, so it sidesteps that bug entirely.
  fonts.packages = import ../../home/shared/assets/fonts/enabled-packages.nix {
    inherit lib pkgs;
  };
}
