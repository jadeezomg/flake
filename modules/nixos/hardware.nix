{
  lib,
  pkgs,
  ...
}: {
  hardware.graphics.enable = true;

  # Compressed RAM swap for parallel nix builds (fork overcommit without disk wear).
  zramSwap = {
    enable = lib.mkDefault true;
    memoryPercent = lib.mkDefault 50;
  };

  # --- Audio (pipewire stack) ---
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber.enable = true;
    };
    # --- Printing ---
    printing.enable = true;
    # --- Storage ---
    udisks2.enable = true;
  };
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    # --- Audio admin ---
    alsa-utils
    pamixer
    pavucontrol
    playerctl
    wireplumber

    # --- Storage / filesystems ---
    ntfs3g
    ntfsprogs

    # --- Graphics libs (pulled in by various desktop apps) ---
    glib
    gsettings-desktop-schemas
    libGL
    libGLU
    libva
    mesa

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

    # --- Display / video ---
    autorandr
    brightnessctl
    wdisplays

    # --- Input ---
    evtest
    libinput

    # --- Power ---
    upower
  ];
}
