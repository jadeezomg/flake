{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
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
