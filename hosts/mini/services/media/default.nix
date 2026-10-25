# Mini media: nixflix automation + dual playback (Plex + Jellyfin).
# Docs: docs/hosts/mini.md § Media stack
# Policy: docs/adr/0003-dual-playback-plex-and-jellyfin.md
{ ... }:
{
  imports = [
    ./storage.nix
    ./nixflix
    ./native.nix
    ./playback-cache.nix
    ./plex-connect.nix
    ./proxy.nix
    ./seerr.nix
  ];
}
