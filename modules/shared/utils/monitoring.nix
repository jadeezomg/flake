{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    btop # Better htop alternative
    mesa-demos # Info for OpenGL & Mesa
    hyperfine # Command-line benchmarking tool
    nmon # System monitoring tool
    psmisc # killall, pstree, etc.
    lm_sensors # Tools for reading hardware sensors
  ];
}
