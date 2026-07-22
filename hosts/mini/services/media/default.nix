# Mini media: nixflix automation + dual playback (Plex + Jellyfin).
# Docs: docs/hosts/mini-media.md
# Policy: docs/adr/0003-dual-playback-plex-and-jellyfin.md
{ ... }:
{
  imports = [
    ./storage.nix
    ./nixflix
    ./native.nix
    ./proxy.nix
  ];
}
