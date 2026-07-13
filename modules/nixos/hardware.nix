# Hardware baseline for every Linux host (server included). Audio, printing,
# and desktop peripheral tooling live in modules/profiles/desktop/peripherals.nix.
{
  lib,
  pkgs,
  ...
}:
{
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
