{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # --- Linux-specific Graphics Libraries ---
    gdb # GNU Project Debugger
    glib
    gsettings-desktop-schemas
    libGL
    libGLU
    mesa # Open source 3D graphics library

    # --- Linux-specific Core Utilities ---
    coreutils-prefixed # Prefixed version of coreutils
    util-linux # Includes lscpu
    uutils-coreutils-noprefix # An improvement over coreutils

    # --- Linux-specific Hardware Information Tools ---
    inxi # My swiss army knife
    pciutils # lspci
    smartmontools # S.M.A.R.T. monitoring
    usbutils # lsusb

    # --- Display tools (Linux) ---
    autorandr # Automatically select a display configuration based on connected devices

    # --- Hardware Testing ---
    stress # Perform stress tests on CPU

    # --- Video Tools ---
    libva # Video acceleration API

    # --- Audio Tools ---
    alsa-utils # ALSA utilities

    # --- Hardware Information Tools ---
    hwinfo # Hardware detection tool
    dmidecode # System hardware details
    dool # System statistics tool (dstat replacement)
    lshw # List hardware
    read-edid # EDID information
    upower # D-Bus service for power management
    evtest # Live-test keyboards
    libinput # Handle inputs in Wayland
  ];
}
