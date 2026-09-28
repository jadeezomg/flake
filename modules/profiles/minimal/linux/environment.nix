# XDG MIME defaults moved to ../../desktop/mime.nix. They point at apps only
# desktop hosts install, so headless hosts must not carry them.
{ lib, ... }:
{
  gtk.gtk4.theme = lib.mkForce null;

  # dconf needs the user dconf D-Bus service (graphical session); on headless
  # hosts HM activation would touch it for nothing. Off by default — the
  # desktop profile (../desktop/dconf.nix) turns it on with its settings.
  # The pear-desktop entry lives in apps/media.
  dconf.enable = lib.mkDefault false;
}
