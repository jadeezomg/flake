{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    mesa-demos # Info for OpenGL & Mesa
    nmon # System monitoring tool
    psmisc # killall, pstree, etc.
    lm_sensors # Tools for reading hardware sensors
  ];
}
