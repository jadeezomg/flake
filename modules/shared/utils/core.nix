{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gdb # GNU Project Debugger
    glib
    gsettings-desktop-schemas
    libGL
    libGLU
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
    jujutsu # Git-compatible DVCS
    jjui # Jujutsu UI

    # --- Hardware Information Tools ---
    inxi # My swiss army knife
    pciutils # lspci
    smartmontools # S.M.A.R.T. monitoring
    usbutils # lsusb

    # display tools
    autorandr # Automatically select a display configuration based on connected devices

    # --- Hardware Testing ---
    stress # Perform stress tests on CPU
  ];
}
