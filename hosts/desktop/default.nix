{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./gpu.nix
    ./display.nix
    ./profiles.nix
  ];

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/777dc8ab-1fe3-4b38-b6e2-9976491ce434";
    fsType = "ext4";
    options = ["defaults" "x-gvfs-show"];
  };

  programs.coolercontrol = {
    enable = true;
  };

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
