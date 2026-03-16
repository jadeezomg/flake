{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./audio.nix
    ./printers.nix
    ./storage.nix
    ./video.nix
  ];
}
