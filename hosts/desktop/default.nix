{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./profiles.nix
    ./corecycler.nix
  ];

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/777dc8ab-1fe3-4b38-b6e2-9976491ce434";
    fsType = "ext4";
    options = [
      "defaults"
      "x-gvfs-show"
    ];
  };

  programs.coolercontrol = {
    enable = true;
  };
}
