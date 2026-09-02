{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./input.nix
    ./power.nix
    ./profiles.nix
  ];

  environment.systemPackages = with pkgs; [
    framework-tool
    framework-tool-tui
  ];
}
