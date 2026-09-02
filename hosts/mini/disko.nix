{ dotfilesLib, lib, ... }:
let
  inherit (dotfilesLib.expiry { inherit lib; } "hosts/mini/disko.nix") todo;
in
{
  disko.devices.disk = {
    system = {
      type = "disk";
      # TODO(blocker): REPLACE_ME is still in place while mini is deployed and
      # serving. Either this file is stale after the install and must be
      # updated from `ls -l /dev/disk/by-id/` on mini, or a reinstall would
      # target a device that does not exist. Resolve before any disko run.
      # TODO: replace with the real 256 GB system SSD /dev/disk/by-id/nvme-... path
      # before running `disko --mode disko --flake .#mini`. Identify on the live ISO
      # via `ls -l /dev/disk/by-id/ | grep nvme` and verify by model/serial/size.
      device = todo "system disk id is the REPLACE_ME placeholder; read the real id from /dev/disk/by-id on mini" "/dev/disk/by-id/nvme-SYSTEM_256GB_REPLACE_ME";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "nixos-system"
                "-f"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd:3"
                    "noatime"
                    "discard=async"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:3"
                    "noatime"
                    "discard=async"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd:3"
                    "noatime"
                    "discard=async"
                  ];
                };
                "@var-log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd:3"
                    "noatime"
                    "discard=async"
                  ];
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd:3"
                    "noatime"
                    "discard=async"
                  ];
                };
              };
            };
          };
        };
      };
    };

    applications = {
      type = "disk";
      # TODO: replace with the real 2 TB application-storage SSD
      # /dev/disk/by-id/nvme-... path before running disko. This disk is mounted
      # at /srv for service/application data; the Nix store stays on the 256 GB
      # system SSD.
      device = todo "applications disk id is the REPLACE_ME placeholder; read the real id from /dev/disk/by-id on mini" "/dev/disk/by-id/nvme-APPLICATIONS_2TB_REPLACE_ME";
      content = {
        type = "gpt";
        partitions.srv = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "application-storage"
              "-f"
            ];
            subvolumes."@srv" = {
              mountpoint = "/srv";
              mountOptions = [
                "compress=zstd:3"
                "noatime"
                "discard=async"
              ];
            };
          };
        };
      };
    };
  };
}
