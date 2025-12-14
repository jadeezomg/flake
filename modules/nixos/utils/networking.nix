{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wirelesstools # Wireless network configuration tools
  ];
}
