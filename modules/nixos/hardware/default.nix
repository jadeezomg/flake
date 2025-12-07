{ ... }:

{
  imports = [
    ./audio.nix
    ./battery.nix
    ./bluetooth.nix
    ./keyboard.nix
    ./mouse.nix
    ./network.nix
    ./printers.nix
    ./storage.nix
    ./video.nix
  ];

  # General hardware modules can be imported here
  # Host-specific hardware configuration should be in hosts/<hostname>/default.nix
}
