# Hardware baseline for every Linux host (server included). Audio, printing,
# and desktop peripheral tooling live in modules/profiles/desktop/peripherals.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # CPU microcode for both vendors. Each option is a no-op on the other
  # vendor's CPU, so one shared line replaces the per-host generated ones.
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Firmware updates over LVFS (BIOS, SSDs, Intel CSME, peripherals).
  services.fwupd.enable = true;

  # Compressed RAM swap for parallel nix builds (fork overcommit without disk wear).
  zramSwap = {
    enable = lib.mkDefault true;
    memoryPercent = lib.mkDefault 50;
  };

  # --- Storage ---
  services.udisks2.enable = true;

  environment.systemPackages = with pkgs; [
    # --- Storage / filesystems ---
    ntfs3g
    ntfsprogs

    # --- Hardware inspection ---
    dmidecode
    dool # dstat replacement
    hwinfo
    inxi
    lshw
    pciutils # lspci
    read-edid
    smartmontools
    usbutils # lsusb
    util-linux # lscpu et al.

    # --- Benchmarks ---
    y-cruncher

    # --- Sensors / monitoring ---
    lm_sensors
    nmon
    psmisc # killall, pstree
  ];
}
