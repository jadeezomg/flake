# Wireless radios — wifi tooling + bluetooth. Combined trait: machines with
# a radio module almost always have both (wifi/BT combo cards).
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.dotfiles.hardware.wireless.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = config.dotfiles.profiles.desktop.enable;

    environment.systemPackages = [pkgs.wirelesstools];
  };
}
