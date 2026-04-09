{...}: {
  imports = [
    ./audio.nix
    ./printers.nix
    ./storage.nix
    ./video.nix
  ];

  hardware.graphics.enable = true;
}
