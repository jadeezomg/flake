{
  disko.devices.disk.main = {
    type = "disk";
    # TODO: replace with the real /dev/disk/by-id/nvme-... path before running
    # `disko --mode disko --flake .#mini`. Identify on the live ISO via
    # `ls -l /dev/disk/by-id/ | grep nvme`.
    device = "/dev/disk/by-id/nvme-REPLACE_ME";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-L" "nixos" "-f"];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = ["compress=zstd:3" "noatime"];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = ["compress=zstd:3"];
              };
              "@var-log" = {
                mountpoint = "/var/log";
                mountOptions = ["compress=zstd:3" "noatime"];
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
              };
            };
          };
        };
      };
    };
  };
}
