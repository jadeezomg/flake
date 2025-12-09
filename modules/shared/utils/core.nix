{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gdb # GNU Project Debugger
    glib
    gsettings-desktop-schemas
    libGL
    libGLU
    libva # Video acceleration API
    mesa # Open source 3D graphics library

    # --- Core System Utilities ---
    coreutils # Basic GNU tools
    coreutils-prefixed # Prefixed version of coreutils
    util-linux # Includes lscpu
    uutils-coreutils-noprefix # An improvement over coreutils

    # --- Build Essentials ---
    gnumake # Make files
    gnutls # GNU transport layer security library
    gcc # GNU compiler collection
    pkg-config # Package information finder

    # --- Version Control ---
    git
    hwinfo # Hardware detection tool from openSUSE
    jujutsu # Git-compatible DVCS
    jjui # Jujutsu UI

    # --- Hardware Information Tools ---
    dmidecode # System hardware details
    dool # System statistics tool (dstat replacement)
    inxi # My swiss army knife
    lshw # List hardware
    pciutils # lspci
    read-edid # EDID information
    smartmontools # S.M.A.R.T. monitoring
    upower # D-Bus service for power management
    usbutils # lsusb
    evtest # Live-test keyboards
    libinput # Handle inputs in Wayland

    # display tools
    autorandr # Automatically select a display configuration based on connected devices

    # --- Audio Tools ---
    alsa-utils # ALSA utilities

    # --- Hardware Testing ---
    stress # Perform stress tests on CPU
  ];
}
